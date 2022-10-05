//
//  TokenProviderType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.08.2021.
//

import AlphaWalletCore
import PromiseKit
import BigInt

// NOTE: Think about the name, more fittable name is needed
public protocol TokenProviderType: class {
    func getContractName(for address: AlphaWallet.Address) -> Promise<String>
    func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String>
    func getDecimals(for address: AlphaWallet.Address) -> Promise<UInt8>
    func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType>
    func getEthBalance(for address: AlphaWallet.Address) -> Promise<Balance>
    func getERC20Balance(for address: AlphaWallet.Address) -> Promise<BigInt>
    func getERC875Balance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getERC721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]>
    func getERC721Balance(for address: AlphaWallet.Address) -> Promise<[String]>
}

public class TokenProvider: TokenProviderType {
    private let account: Wallet
    private let numberOfTimesToRetryFetchContractData = 2
    private let server: RPCServer
    private let analytics: AnalyticsLogger
    private let queue: DispatchQueue?
    private lazy var isERC1155ContractDetector = IsErc1155Contract(forServer: server)
    private lazy var getEthBalance = GetEthBalance(forServer: server, analytics: analytics, queue: queue)

    public init(account: Wallet, server: RPCServer, analytics: AnalyticsLogger, queue: DispatchQueue? = .none) {
        self.account = account
        self.queue = queue
        self.server = server
        self.analytics = analytics
    }

    public func getEthBalance(for address: AlphaWallet.Address) -> Promise<Balance> {
        //NOTE: retrying is performing via APIKit.session request
        return getEthBalance.getBalance(for: address)
    }
    
    public func getContractName(for address: AlphaWallet.Address) -> Promise<String> {
        let server = server
        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                GetContractName(forServer: server)
                    .getName(for: address)
            }
        }
    }

    public func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String> {
        let server = server
        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                GetContractSymbol(forServer: server)
                    .getSymbol(for: address)
            }
        }
    }

    public func getDecimals(for address: AlphaWallet.Address) -> Promise<UInt8> {
        let server = server
        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                GetContractDecimals(forServer: server)
                    .getDecimals(for: address)
            }
        }
    }

    public func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType> {
        Promise { seal in
            getTokenType(for: address) { tokenType in
                seal.fulfill(tokenType)
            }
        }
    }

    public func getERC20Balance(for address: AlphaWallet.Address) -> Promise<BigInt> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                GetErc20Balance(forServer: server, queue: queue)
                    .getBalance(for: account, contract: address)
            }
        }
    }

    public func getERC875Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                GetErc875Balance(forServer: server, queue: queue)
                    .getERC875TokenBalance(for: account, contract: address)
            }
        }

    }

    public func getERC721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                GetErc721ForTicketsBalance(forServer: server, queue: queue)
                    .getERC721ForTicketsTokenBalance(for: account, contract: address)
            }
        }
    }

    public func getERC721Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                GetErc721Balance(forServer: server, queue: queue)
                    .getERC721TokenBalance(for: account, contract: address)
            }
        }
    }

    fileprivate static func shouldRetry(error: Error) -> Bool {
        return true
    }

    private func getTokenType(for address: AlphaWallet.Address, completion: @escaping (TokenType) -> Void) {
        enum Erc721Type {
            case erc721
            case erc721ForTickets
            case notErc721
        }

        let numberOfTimesToRetryFetchContractData = numberOfTimesToRetryFetchContractData
        let server = server

        let isErc875Promise = firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                //Function hash is "0x4f452b9a". This might cause many "execution reverted" RPC errors
                //TODO rewrite flow so we reduce checks for this as it causes too many "execution reverted" RPC errors and looks scary when we look in Charles proxy. Maybe check for ERC20 (via EIP165) as well as ERC721 in parallel first, then fallback to this ERC875 check
                IsErc875Contract(forServer: server)
                    .getIsERC875Contract(for: address)
            }.recover { _ -> Promise<Bool> in
                return .value(false)
            }
        }

        let isErc721Promise = firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                IsErc721Contract(forServer: server).getIsERC721Contract(for: address)
            }
        }.then { isERC721 -> Promise<Erc721Type> in
            if isERC721 {
                return attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                    IsErc721ForTicketsContract(forServer: server)
                        .getIsERC721ForTicketContract(for: address)
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
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
                self.isERC1155ContractDetector
                    .getIsERC1155Contract(for: address)
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
}

