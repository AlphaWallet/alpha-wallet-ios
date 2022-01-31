//
//  TokenProviderType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.08.2021.
//

import PromiseKit
import Result
import BigInt

// NOTE: Think about the name, more fittable name is needed
protocol TokenProviderType: class { 
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

class TokenProvider: TokenProviderType {
    private let account: Wallet
    private let numberOfTimesToRetryFetchContractData = 2
    private let server: RPCServer
    private let queue: DispatchQueue?

    init(account: Wallet, server: RPCServer, queue: DispatchQueue? = .none) {
        self.account = account
        self.queue = queue
        self.server = server
    }

    func getEthBalance(for address: AlphaWallet.Address) -> Promise<Balance> {
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetNativeCryptoCurrencyBalanceCoordinator(forServer: server, queue: queue)
                    .getBalance(for: address)
            }
        }
    }

    func getContractName(for address: AlphaWallet.Address) -> Promise<String> {
        let server = server
        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetNameCoordinator(forServer: server)
                    .getName(for: address)
            }
        }
    }

    func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String> {
        let server = server
        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetSymbolCoordinator(forServer: server)
                    .getSymbol(for: address)
            }
        }
    }

    func getDecimals(for address: AlphaWallet.Address) -> Promise<UInt8> {
        let server = server
        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetDecimalsCoordinator(forServer: server)
                    .getDecimals(for: address)
            }
        }
    }

    func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType> {
        Promise { seal in
            getTokenType(for: address) { tokenType in
                seal.fulfill(tokenType)
            }
        }
    }

    func getERC20Balance(for address: AlphaWallet.Address) -> Promise<BigInt> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetERC20BalanceCoordinator(forServer: server, queue: queue)
                    .getBalance(for: account, contract: address)
            }
        }
    }

    func getERC875Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetERC875BalanceCoordinator(forServer: server, queue: queue)
                    .getERC875TokenBalance(for: account, contract: address)
            }
        }

    }

    func getERC721ForTicketsBalance(for address: AlphaWallet.Address) -> Promise<[String]> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetERC721ForTicketsBalanceCoordinator(forServer: server, queue: queue)
                    .getERC721ForTicketsTokenBalance(for: account, contract: address)
            }
        }
    }

    func getERC721Balance(for address: AlphaWallet.Address) -> Promise<[String]> {
        let account = account.address
        let server = server
        let queue = queue

        return firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetERC721BalanceCoordinator(forServer: server, queue: queue)
                    .getERC721TokenBalance(for: account, contract: address)
            }.map { balance -> [String] in
                if balance >= Int.max {
                    throw AnyError(Web3Error(description: ""))
                } else {
                    return [String](repeating: "0", count: Int(balance))
                }
            }
        }
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
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetIsERC875ContractCoordinator(forServer: server)
                    .getIsERC875Contract(for: address)
            }.recover { _ -> Promise<Bool> in
                return .value(false)
            }
        }

        let isErc721Promise = firstly {
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetIsERC721ContractCoordinator(forServer: server).getIsERC721Contract(for: address)
            }
        }.then { isERC721 -> Promise<Erc721Type> in
            if isERC721 {
                return attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                    GetIsERC721ForTicketsContractCoordinator(forServer: server)
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
            attempt(maximumRetryCount: numberOfTimesToRetryFetchContractData) {
                GetIsERC1155ContractCoordinator(forServer: server)
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
            error(value: e, pref: "isErc721Promise", address: address)
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
            error(value: e, pref: "isErc875Promise", address: address)
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
            error(value: e, pref: "isErc1155Promise", address: address)
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
            error(value: e, pref: "isErc20Promise", address: address)
        })
    } 
}

