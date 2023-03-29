//
//  ImportToken.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.06.2022.
//

import Foundation
import Combine
import BigInt

public protocol TokenImportable {
    func importToken(ercToken: ErcToken, shouldUpdateBalance: Bool) -> Token
    func importToken(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool) -> AnyPublisher<Token, ImportToken.ImportTokenError>
}

extension TokenImportable {

    func importToken(ercToken: ErcToken) -> Token {
        importToken(ercToken: ercToken, shouldUpdateBalance: true)
    }

    func importToken(for contract: AlphaWallet.Address) -> AnyPublisher<Token, ImportToken.ImportTokenError> {
        importToken(for: contract, onlyIfThereIsABalance: false)
    }
}

public protocol TokenOrContractFetchable: ContractDataFetchable {
    func fetchTokenOrContract(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool) -> AnyPublisher<TokenOrContract, ImportToken.ImportTokenError>
}

extension TokenOrContractFetchable {
    func fetchTokenOrContract(for contract: AlphaWallet.Address) -> AnyPublisher<TokenOrContract, ImportToken.ImportTokenError> {
        fetchTokenOrContract(for: contract, onlyIfThereIsABalance: false)
    }
}

//NOTE: actually its internal, public for tests
public protocol ContractDataFetchable {
    func fetchContractData(for contract: AlphaWallet.Address) -> AnyPublisher<ContractData, Never>
}

public final class ContractDataFetcher: ContractDataFetchable {
    enum FetcherError: Error {
        case serverIsDisabled
    }

    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let reachability: ReachabilityManagerProtocol
    private let wallet: Wallet
    private let ercTokenProvider: TokenProviderType

    public init(wallet: Wallet,
                ercTokenProvider: TokenProviderType,
                assetDefinitionStore: AssetDefinitionStore,
                analytics: AnalyticsLogger,
                reachability: ReachabilityManagerProtocol) {

        self.assetDefinitionStore = assetDefinitionStore
        self.wallet = wallet
        self.ercTokenProvider = ercTokenProvider
        self.analytics = analytics
        self.reachability = reachability
    }

    public func fetchContractData(for contract: AlphaWallet.Address) -> AnyPublisher<ContractData, Never> {
        let detector = ContractDataDetector(
            contract: contract,
            wallet: wallet.address,
            ercTokenProvider: ercTokenProvider,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            reachability: reachability)

        return detector.fetch()
    }
}

extension ImportToken.ImportTokenError {
    init(error: Error) {
        if let e = error as? ImportToken.ImportTokenError {
            self = e
        } else {
            self = .internal(error: error)
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

    private var inFlightPublishers: [String: AnyPublisher<TokenOrContract, ImportTokenError>] = [:]
    private let reachability: ReachabilityManagerProtocol
    private let server: RPCServer

    public init(tokensDataStore: TokensDataStore,
                contractDataFetcher: ContractDataFetchable,
                server: RPCServer,
                reachability: ReachabilityManagerProtocol) {

        self.reachability = reachability
        self.server = server
        self.tokensDataStore = tokensDataStore
        self.contractDataFetcher = contractDataFetcher
    }

    public func importToken(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> AnyPublisher<Token, ImportTokenError> {
        return Just(server)
            .receive(on: queue)
            .setFailureType(to: ImportTokenError.self)
            .flatMap { [tokensDataStore, queue, server] server -> AnyPublisher<Token, ImportTokenError> in
                if let token = tokensDataStore.token(for: contract, server: server) {
                    return .just(token)
                } else {
                    return self.fetchTokenOrContract(for: contract, onlyIfThereIsABalance: onlyIfThereIsABalance)
                        .flatMap { tokenOrContract -> AnyPublisher<Token, ImportTokenError> in
                            //FIXME: looks like blocking access to realm doesn't work well, after adding a new token and retrieving its value from bd it returns nil, adding delay in 1 sec helps to return a new token.
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

    public func fetchContractData(for contract: AlphaWallet.Address) -> AnyPublisher<ContractData, Never> {
        return contractDataFetcher.fetchContractData(for: contract)
    }

    public func fetchTokenOrContract(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> AnyPublisher<TokenOrContract, ImportTokenError> {
        Just(contract)
            .receive(on: queue)
            .setFailureType(to: ImportTokenError.self)
            .flatMap { [weak self, queue, server, contractDataFetcher] contract -> AnyPublisher<TokenOrContract, ImportTokenError> in
                //Useful to check because we are/might action-only TokenScripts for native crypto currency
                guard contract != Constants.nativeCryptoAddressInDatabase else {
                    return .fail(ImportTokenError.nativeCryptoNotSupported)
                }

                let key = "\(contract.hashValue)-\(onlyIfThereIsABalance)-\(server)"

                if let publisher = self?.inFlightPublishers[key] {
                    return publisher
                } else {
                    let publisher = contractDataFetcher.fetchContractData(for: contract)
                        .tryCompactMap { data -> TokenOrContract? in
                            switch data {
                            case .name, .symbol, .balance, .decimals:
                                return nil
                            case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                                guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !balance.isEmpty) else {
                                    throw ImportTokenError.zeroBalanceDetected
                                }
                                let ercToken = ErcToken(
                                    contract: contract,
                                    server: server,
                                    name: name,
                                    symbol: symbol,
                                    decimals: 0,
                                    type: tokenType,
                                    value: "0",
                                    balance: balance)

                                return .ercToken(ercToken)
                            case .fungibleTokenComplete(let name, let symbol, let decimals, let value, let tokenType):
                                //NOTE: we want to make get balance for fungible token, fetching for token from data source might be unusefull as token hasn't created yes (when we fetch for a new contract) so we fetch tokens balance sync on `getFungibleBalanceQueue` and return result on `.main` queue
                                // one more additional network call, shouldn't be complex.
                                guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && (value != .zero)) else {
                                    throw ImportTokenError.zeroBalanceDetected
                                }

                                let ercToken = ErcToken(
                                    contract: contract,
                                    server: server,
                                    name: name,
                                    symbol: symbol,
                                    decimals: decimals,
                                    type: tokenType,
                                    value: value,
                                    balance: .balance(["0"]))

                                return .ercToken(ercToken)
                            case .delegateTokenComplete:
                                return .delegateContracts([AddressAndRPCServer(address: contract, server: server)])
                            case .failed(let networkReachable, let error):
                                //Receives first received error, e.g name, symbol, token type, decimals
                                //TODO: maybe its need to handle some cases of error here?
                                if networkReachable {
                                    return .deletedContracts([AddressAndRPCServer(address: contract, server: server)])
                                } else {
                                    throw ImportTokenError.internal(error: error)
                                }
                            }
                        }.mapError { ImportToken.ImportTokenError(error: $0) }
                        .receive(on: queue)
                        .handleEvents(receiveCompletion: { _ in self?.inFlightPublishers[key] = nil })
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPublishers[key] = publisher

                    return publisher
                }
            }.eraseToAnyPublisher()
    }
}
