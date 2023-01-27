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
    func importTokenPublisher(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> AnyPublisher<Token, ImportToken.ImportTokenError>
}

public protocol TokenOrContractFetchable: ContractDataFetchable {
    func fetchTokenOrContractPublisher(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool) -> AnyPublisher<TokenOrContract, ImportToken.ImportTokenError>
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

    public init(sessionProvider: SessionsProvider,
                assetDefinitionStore: AssetDefinitionStore,
                analytics: AnalyticsLogger,
                reachability: ReachabilityManagerProtocol) {

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
    public enum ImportTokenError: Error {
        case nativeCryptoNotSupported
        case serverIsDisabled
        case zeroBalanceDetected
        case `internal`(error: Error)
        case notContractOrFailed(TokenOrContract)
    }

    private let contractDataFetcher: ContractDataFetchable
    private let tokensDataStore: TokensDataStore
    private let queue = DispatchQueue(label: "org.alphawallet.swift.importToken")
    private var inFlightPromises: [String: Promise<TokenOrContract>] = [:]
    private var inFlightPublishers: [String: AnyPublisher<TokenOrContract, ImportTokenError>] = [:]
    private let reachability = ReachabilityManager()

    public init(tokensDataStore: TokensDataStore, contractDataFetcher: ContractDataFetchable) {
        self.tokensDataStore = tokensDataStore
        self.contractDataFetcher = contractDataFetcher
    }

    public func importTokenPublisher(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> AnyPublisher<Token, ImportTokenError> {
        return Just(server)
            .receive(on: queue)
            .setFailureType(to: ImportTokenError.self)
            .flatMap { [tokensDataStore, queue] server -> AnyPublisher<Token, ImportTokenError> in
                if let token = tokensDataStore.token(forContract: contract, server: server) {
                    return .just(token)
                } else {
                    return self.fetchTokenOrContractPublisher(for: contract, server: server, onlyIfThereIsABalance: onlyIfThereIsABalance)
                        .flatMap { tokenOrContract -> AnyPublisher<Token, ImportTokenError> in
                            //FIXME: looks like blocking access to realm doesn't work well, after adding a new token and retrieving its value from bd, returns nil, adding delay in 1 sec to return a new token.
                            if let token = tokensDataStore.addOrUpdate(tokensOrContracts: [tokenOrContract]).first {
                                return .just(token)
                                    .delay(for: .seconds(1), scheduler: queue)
                                    .eraseToAnyPublisher()
                            } else {
                                return .fail(ImportTokenError.notContractOrFailed(tokenOrContract))
                            }
                        }.eraseToAnyPublisher()
                }
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func importToken(ercToken: ErcToken, shouldUpdateBalance: Bool = true) -> Token {
        let tokens = tokensDataStore.addOrUpdate(with: [.add(ercToken: ercToken, shouldUpdateBalance: shouldUpdateBalance)])

        return tokens[0]
    }

    public func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        contractDataFetcher.fetchContractData(for: contract, server: server, completion: completion)
    }

    public func fetchTokenOrContractPublisher(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> AnyPublisher<TokenOrContract, ImportTokenError> {
        Just(contract)
            .receive(on: queue)
            .setFailureType(to: ImportTokenError.self)
            .flatMap { [queue] contract -> AnyPublisher<TokenOrContract, ImportTokenError> in
                //Useful to check because we are/might action-only TokenScripts for native crypto currency
                guard contract != Constants.nativeCryptoAddressInDatabase else {
                    return .fail(ImportTokenError.nativeCryptoNotSupported)
                }

                let key = "\(contract.hashValue)-\(onlyIfThereIsABalance)-\(server)"

                if let publisher = self.inFlightPublishers[key] {
                    return publisher
                } else {
                    let publisher = Future<TokenOrContract, ImportTokenError> { seal in
                        self.fetchContractData(for: contract, server: server) { data in
                            switch data {
                            case .name, .symbol, .balance, .decimals:
                                break
                            case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                                guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !balance.isEmpty) else {
                                    seal(.failure(ImportTokenError.zeroBalanceDetected))
                                    return
                                }
                                let ercToken = ErcToken(contract: contract, server: server, name: name, symbol: symbol, decimals: 0, type: tokenType, value: "0", balance: balance)

                                seal(.success(.ercToken(ercToken)))
                            case .fungibleTokenComplete(let name, let symbol, let decimals, let value, let tokenType):
                                //NOTE: we want to make get balance for fungible token, fetching for token from data source might be unusefull as token hasn't created yes (when we fetch for a new contract) so we fetch tokens balance sync on `getFungibleBalanceQueue` and return result on `.main` queue
                                // one more additional network call, shouldn't be complex.
                                guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && (value != .zero)) else {
                                    seal(.failure(ImportTokenError.zeroBalanceDetected))
                                    return
                                }

                                let ercToken = ErcToken(contract: contract, server: server, name: name, symbol: symbol, decimals: decimals, type: tokenType, value: value, balance: .balance(["0"]))

                                seal(.success(.ercToken(ercToken)))
                            case .delegateTokenComplete:
                                seal(.success(.delegateContracts([AddressAndRPCServer(address: contract, server: server)])))
                            case .failed(let networkReachable, let error):
                                //Receives first received error, e.g name, symbol, token type, decimals
                                //TODO: maybe its need to handle some cases of error here?
                                if networkReachable {
                                    seal(.success(.deletedContracts([AddressAndRPCServer(address: contract, server: server)])))
                                } else {
                                    seal(.failure(ImportTokenError.internal(error: error)))
                                }
                            }
                        }
                    }.receive(on: queue)
                    .handleEvents(receiveCompletion: { _ in self.inFlightPublishers[key] = nil })
                    .eraseToAnyPublisher()

                    self.inFlightPublishers[key] = publisher

                    return publisher
                }
            }.eraseToAnyPublisher()
    }
}
