//
//  ImportToken.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.06.2022.
//

import Foundation
import PromiseKit
import Combine
import BigInt

public protocol TokenImportable {
    func importToken(ercToken: ErcToken, shouldUpdateBalance: Bool) -> Token
    func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> Promise<Token>
}

public protocol TokenOrContractFetchable: ContractDataFetchable {
    func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> Promise<TokenOrContract>
}

//NOTE: actually its internal, public for tests
public protocol ContractDataFetchable {
    func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void)
}

public final class ContractDataFetcher: ContractDataFetchable {
    enum FetcherError: Error {
        case serverIsDisabled
    }

    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let reachability: ReachabilityManagerProtocol
    private let sessionProvider: SessionsProvider

    public init(sessionProvider: SessionsProvider, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, reachability: ReachabilityManagerProtocol) {
        self.assetDefinitionStore = assetDefinitionStore
        self.sessionProvider = sessionProvider
        self.analytics = analytics
        self.reachability = reachability
    }

    public func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        if let session = sessionProvider.session(for: server) {
            let detector = ContractDataDetector(address: contract, session: session, assetDefinitionStore: assetDefinitionStore, analytics: analytics, reachability: reachability)
            detector.fetch(completion: completion)
        } else {
            completion(.failed(networkReachable: reachability.isReachable, error: FetcherError.serverIsDisabled))
        }
    }
}

final public class ImportToken: TokenImportable, TokenOrContractFetchable {
    enum ImportTokenError: Error {
        case serverIsDisabled
        case zeroBalanceDetected
        case `internal`(error: Error)
        case notContractOrFailed(TokenOrContract)
    }

    private let contractDataFetcher: ContractDataFetchable
    private let tokensDataStore: TokensDataStore
    private var cancelable = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "org.alphawallet.swift.importToken")
    private var inFlightPromises: [String: Promise<TokenOrContract>] = [:]
    private let reachability = ReachabilityManager()

    public init(tokensDataStore: TokensDataStore, contractDataFetcher: ContractDataFetchable) {
        self.tokensDataStore = tokensDataStore
        self.contractDataFetcher = contractDataFetcher
    }

    //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    public func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<Token> {
        firstly {
            .value(server)
        }.then(on: queue, { [queue, tokensDataStore] server -> Promise<Token> in
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

    public func importToken(ercToken: ErcToken, shouldUpdateBalance: Bool = true) -> Token {
        let tokens = tokensDataStore.addOrUpdate(with: [.add(ercToken: ercToken, shouldUpdateBalance: shouldUpdateBalance)])

        return tokens[0]
    }

    public func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        contractDataFetcher.fetchContractData(for: contract, server: server, completion: completion)
    }

    public func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<TokenOrContract> {
        firstly {
            .value(contract)
        }.then(on: queue, { [queue] contract -> Promise<TokenOrContract> in
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
                        case .fungibleTokenComplete(let name, let symbol, let decimals, let value, let tokenType):
                            //NOTE: we want to make get balance for fungible token, fetching for token from data source might be unusefull as token hasn't created yes (when we fetch for a new contract) so we fetch tokens balance sync on `getFungibleBalanceQueue` and return result on `.main` queue
                            // one more additional network call, shouldn't be complex.
                            guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && (value != .zero)) else {
                                seal.reject(ImportTokenError.zeroBalanceDetected)
                                return
                            }

                            let ercToken = ErcToken(contract: contract, server: server, name: name, symbol: symbol, decimals: decimals, type: tokenType, value: value, balance: .balance(["0"]))

                            seal.fulfill(.ercToken(ercToken))
                        case .delegateTokenComplete:
                            seal.fulfill(.delegateContracts([AddressAndRPCServer(address: contract, server: server)]))
                        case .failed(let networkReachable, let error):
                            //Receives first received error, e.g name, symbol, token type, decimals
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
