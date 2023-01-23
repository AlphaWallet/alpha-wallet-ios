//
//  GetTokenType.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.10.2022.
//

import AlphaWalletCore
import PromiseKit
import BigInt
import Combine

final class GetTokenType {
    private var inFlightPromises: [String: AnyPublisher<TokenType, SessionTaskError>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getTokenType")
    private lazy var isErc1155Contract = IsErc1155Contract(blockchainProvider: blockchainProvider)
    private lazy var isErc875Contract = IsErc875Contract(blockchainProvider: blockchainProvider)
    private lazy var erc721ForTickers = IsErc721ForTicketsContract(blockchainProvider: blockchainProvider)
    private lazy var erc721 = IsErc721Contract(blockchainProvider: blockchainProvider)

    private let blockchainProvider: BlockchainProvider
    private var cancellable = Set<AnyCancellable>()

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func getTokenType(for address: AlphaWallet.Address) -> AnyPublisher<TokenType, SessionTaskError> {
        return Just(address)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue] address -> AnyPublisher<TokenType, SessionTaskError> in
                let key = address.eip55String
                if let promise = self?.inFlightPromises[key] {
                    return promise
                } else {
                    let promise = Future<TokenType, SessionTaskError> { seal in
                        self?.getTokenType(for: address) { tokenType in
                            seal(.success(tokenType))
                        }
                    }.receive(on: queue)
                    .handleEvents(receiveCompletion: { _ in self?.inFlightPromises[key] = .none })
                    .eraseToAnyPublisher()

                    self?.inFlightPromises[key] = promise

                    return promise
                }
            }.eraseToAnyPublisher()
    }

    /// `getTokenType` doesn't return .nativeCryptoCurrency type, fallback to erc20. Maybe need to throw an error?
    // swiftlint:disable function_body_length
    private func getTokenType(for address: AlphaWallet.Address, completion: @escaping (TokenType) -> Void) {
        enum Erc721Type {
            case erc721
            case erc721ForTickets
            case notErc721
        }

        let numberOfTimesToRetryFetchContractData = 2
        let isErc875Promise = firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) { [isErc875Contract] in
                //Function hash is "0x4f452b9a". This might cause many "execution reverted" RPC errors
                //TODO rewrite flow so we reduce checks for this as it causes too many "execution reverted" RPC errors and looks scary when we look in Charles proxy. Maybe check for ERC20 (via EIP165) as well as ERC721 in parallel first, then fallback to this ERC875 check
                isErc875Contract.getIsERC875Contract(for: address).promise()
            }.recover { _ -> Promise<Bool> in
                return .value(false)
            }
        }

        let isErc721Promise = firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) { [erc721] in
                erc721.getIsERC721Contract(for: address).promise()
            }
        }.then { [erc721ForTickers] isERC721 -> Promise<Erc721Type> in
            if isERC721 {
                return attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    erc721ForTickers.getIsErc721ForTicketContract(for: address).promise()
                }.map { isERC721ForTickets -> Erc721Type in
                    if isERC721ForTickets {
                        return .erc721ForTickets
                    } else {
                        return .erc721
                    }
                }.recover { _ -> Promise<Erc721Type> in
                    return .value(.erc721)
                }
            } else {
                return .value(.notErc721)
            }
        }.recover { _ -> Promise<Erc721Type> in
            return .value(.notErc721)
        }

        let isErc1155Promise = firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) { [isErc1155Contract] in
                isErc1155Contract.getIsErc1155Contract(for: address).promise()
            }.recover { _ -> Promise<Bool> in
                return .value(false)
            }
        }

        firstly {
            isErc721Promise
        }.done { isErc721 in
            switch isErc721 {
            case .erc721:
                completion(.erc721)
            case .erc721ForTickets:
                completion(.erc721ForTickets)
            case .notErc721:
                break
            }
        }.catch({ e in
            logError(e, pref: "isErc721Promise", address: address)
        })

        firstly {
            isErc875Promise
        }.done { isErc875 in
            if isErc875 {
                completion(.erc875)
            } else {
                //no-op
            }
        }.catch({ e in
            logError(e, pref: "isErc875Promise", address: address)
        })

        firstly {
            isErc1155Promise
        }.done { isErc1155 in
            if isErc1155 {
                completion(.erc1155)
            } else {
                //no-op
            }
        }.catch({ e in
            logError(e, pref: "isErc1155Promise", address: address)
        })

        firstly {
            when(fulfilled: isErc875Promise.asVoid(), isErc721Promise.asVoid(), isErc1155Promise.asVoid())
        }.done { _, _, _ in
            if isErc875Promise.value == false && isErc721Promise.value == .notErc721 && isErc1155Promise.value == false {
                completion(.erc20)
            } else {
                //no-op
            }
        }.catch({ e in
            logError(e, pref: "isErc20Promise", address: address)
        })
    }
    // swiftlint:enable function_body_length
}
