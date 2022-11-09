//
//  ImportToken.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.06.2022.
//

import Foundation
import PromiseKit
import Combine

public protocol TokenImportable {
    func importToken(token: ErcToken, shouldUpdateBalance: Bool) -> Token
    func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> Promise<Token>
}

public protocol ContractDataFetchable {
    func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> Promise<TokenOrContract>
    func fetchErc875OrErc20Token(for contract: AlphaWallet.Address, server: RPCServer) -> Promise<TokenOrContract>
    //FIXME: looks like this method can be removed from protocol and updated with `fetchTokenOrContract`
    func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void)
}

open class ImportToken: TokenImportable, ContractDataFetchable {
    enum ImportTokenError: Error {
        case serverIsDisabled
        case zeroBalanceDetected
        case `internal`(error: Error)
        case notContractOrFailed(TokenOrContract)
    }

    private let defaultTokens: [(AlphaWallet.Address, RPCServer)] = [
        (Constants.uefaMainnet, Constants.uefaRpcServer),
        Constants.gnoGnosis,
    ]
    private let sessionProvider: SessionsProvider
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let tokensDataStore: TokensDataStore
    private var cancelable = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "org.alphawallet.swift.importToken")
    private var inFlightPromises: [String: Promise<TokenOrContract>] = [:]
    private let reachability = ReachabilityManager()

    public let wallet: Wallet

    public init(sessionProvider: SessionsProvider, wallet: Wallet, tokensDataStore: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger) {
        self.sessionProvider = sessionProvider
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.wallet = wallet

        addDefaultTokens()
    }

    private func addDefaultTokens() {
        guard !isRunningTests() else { return }

        let defaultTokens = self.defaultTokens
        //NOTE: initally when we set sessions, we want to import uefa tokens, for enabled chain
        sessionProvider.sessions
            .filter { !$0.values.isEmpty }
            .first()
            .sink { _ in
                for (address, server) in defaultTokens {
                    _ = firstly {
                        self.importToken(for: address, server: server, onlyIfThereIsABalance: true)
                    }.done { _ in
                        //no-op
                    }.recover { error in
                        if let error = error as? ImportToken.ImportTokenError {
                            switch error {
                            case .serverIsDisabled:
                                //no-op. Since we didn't check if chain is enabled, we just let it be. But if there are other enum-cases, we don't want to eat the errors, we should re-throw those
                                break
                            case .zeroBalanceDetected:
                                //no-op. We don't import it, possibly because balance is 0
                                break
                            case .notContractOrFailed:
                                throw error
                            case .internal(let error):
                                throw error
                            }
                        } else {
                            throw error
                        }
                    }
                }
            }.store(in: &cancelable)
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    open func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<Token> {
        firstly {
            .value(server)
        }.then(on: queue, { [queue, tokensDataStore] tokenType -> Promise<Token> in
            if let token = tokensDataStore.token(forContract: contract, server: server) {
                return .value(token)
            } else {
                return firstly {
                    self.fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: onlyIfThereIsABalance)
                }.map(on: queue, { [tokensDataStore] tokenOrContract -> Token in
                    if let token = tokensDataStore.addOrUpdate(tokensOrContracts: [tokenOrContract]).first {
                        return token
                    } else {
                        throw ImportTokenError.notContractOrFailed(tokenOrContract)
                    }
                })
            }
        })
    }

    public func fetchErc875OrErc20Token(for contract: AlphaWallet.Address, server: RPCServer) -> Promise<TokenOrContract> {
        firstly {
            .value(server)
        }.then(on: queue, { [queue, sessionProvider] tokenType -> Promise<TokenOrContract> in
            guard let session = sessionProvider.session(for: server) else { return .init(error: ImportTokenError.serverIsDisabled) }

            return session.tokenProvider
                .getTokenType(for: contract)
                .then(on: queue, { [queue, session] tokenType -> Promise<TokenOrContract> in
                    switch tokenType {
                    case .erc875:
                        //TODO long and very similar code below. Extract function
                        return session.tokenProvider.getErc875Balance(for: contract)
                            .then(on: queue, { balance -> Promise<TokenOrContract> in
                                if balance.isEmpty {
                                    return .init(error: ImportTokenError.zeroBalanceDetected)
                                } else {
                                    return self.fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: false)
                                }
                            })
                    case .erc20:
                        return session.tokenProvider.getErc20Balance(for: contract)
                            .then(on: queue, { balance -> Promise<TokenOrContract> in
                                if balance > 0 {
                                    return self.fetchTokenOrContract(for: contract, server: server, onlyIfThereIsABalance: false)
                                } else {
                                    return .init(error: ImportTokenError.zeroBalanceDetected)
                                }
                            })
                    case .erc721, .erc721ForTickets, .erc1155, .nativeCryptocurrency:
                        //Handled in TokenBalanceFetcher.refreshBalanceForErc721Or1155Tokens()
                        return .init(error: ImportTokenError.zeroBalanceDetected)
                    }
                })
        })
    }

    open func importToken(token: ErcToken, shouldUpdateBalance: Bool = true) -> Token {
        let token = tokensDataStore.addCustom(tokens: [token], shouldUpdateBalance: shouldUpdateBalance)

        return token[0]
    }

    open func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        if let session = sessionProvider.session(for: server) {
            let detector = ContractDataDetector(address: contract, session: session, assetDefinitionStore: assetDefinitionStore, analytics: analytics, reachability: reachability)
            detector.fetch(completion: completion)
        } else {
            completion(.failed(networkReachable: reachability.isReachable, error: ImportTokenError.serverIsDisabled))
        }
    }

    open func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<TokenOrContract> {
        firstly {
            .value(contract)
        }.then(on: queue, { [queue, tokensDataStore] contract -> Promise<TokenOrContract> in
            let key = "\(contract.hashValue)-\(onlyIfThereIsABalance)-\(server)"

            if let promise = self.inFlightPromises[key] {
                return promise
            } else {
                let promise = Promise<TokenOrContract> { seal in
                    self.fetchContractData(for: contract, server: server) { data in
                        switch data {
                        case .name, .symbol, .balance, .decimals:
                            break
                        case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                            guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !balance.isEmpty) else {
                                seal.reject(ImportTokenError.zeroBalanceDetected)
                                return
                            }
                            let ercToken = ErcToken(contract: contract, server: server, name: name, symbol: symbol, decimals: 0, type: tokenType, value: "0", balance: balance)

                            seal.fulfill(.ercToken(ercToken))
                        case .fungibleTokenComplete(let name, let symbol, let decimals, let tokenType):
                            let existedToken = tokensDataStore.token(forContract: contract, server: server)
                            let value = existedToken?.value ?? "0"
                            guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !(value != "0")) else {
                                seal.reject(ImportTokenError.zeroBalanceDetected)
                                return
                            }

                            let ercToken = ErcToken(contract: contract, server: server, name: name, symbol: symbol, decimals: decimals, type: tokenType, value: value, balance: .balance(["0"]))
                            seal.fulfill(.ercToken(ercToken))
                        case .delegateTokenComplete:
                            seal.fulfill(.delegateContracts([AddressAndRPCServer(address: contract, server: server)]))
                        case .failed(let networkReachable, let error):
                            //TODO: maybe its need to handle some cases of error here?
                            if networkReachable {
                                seal.fulfill(.deletedContracts([AddressAndRPCServer(address: contract, server: server)]))
                            } else {
                                seal.reject(ImportTokenError.internal(error: error))
                            }
                        }
                    }
                }.ensure(on: queue, {
                    self.inFlightPromises[key] = nil
                })

                self.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}
