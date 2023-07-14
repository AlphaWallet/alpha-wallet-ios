//
//  SessionsProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletTokenScript
import protocol AlphaWalletWeb3.BlockchainCallable

public protocol SessionsProvider: AnyObject {
    var sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> { get }
    var activeSessions: ServerDictionary<WalletSession> { get }

    func start()
    func session(for server: RPCServer) -> WalletSession?
}

open class BaseSessionsProvider: SessionsProvider {
    private let sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never> = .init(.init())
    private let config: Config
    private var cancelable = Set<AnyCancellable>()
    private let blockchainsProvider: BlockchainsProvider
    private let analytics: AnalyticsLogger
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let reachability: ReachabilityManagerProtocol
    private let wallet: Wallet
    private let eventsDataStore: NonActivityEventsDataStore
    private let apiTransporterFactory: ApiTransporterFactory
    public var sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> {
        return sessionsSubject.eraseToAnyPublisher()
    }

    public var activeSessions: ServerDictionary<WalletSession> {
        sessionsSubject.value
    }

    public init(config: Config,
                analytics: AnalyticsLogger,
                blockchainsProvider: BlockchainsProvider,
                tokensDataStore: TokensDataStore,
                eventsDataStore: NonActivityEventsDataStore,
                assetDefinitionStore: AssetDefinitionStore,
                reachability: ReachabilityManagerProtocol,
                wallet: Wallet,
                apiTransporterFactory: ApiTransporterFactory) {

        self.apiTransporterFactory = apiTransporterFactory
        self.eventsDataStore = eventsDataStore
        self.wallet = wallet
        self.reachability = reachability
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensDataStore = tokensDataStore
        self.config = config
        self.analytics = analytics
        self.blockchainsProvider = blockchainsProvider
    }

    public func start() {
        blockchainsProvider
            .blockchains
            .map { [weak self, sessionsSubject] (blockchains: ServerDictionary<BlockchainCallable>) -> ServerDictionary<WalletSession> in
                //TODO unfortunate casting needed due to how/when we extract AlphaWalletTokenScript
                let blockchains = blockchains.mapValues { $0 as! BlockchainProvider }

                guard let strongSelf = self else { return .init() }
                var sessions: ServerDictionary<WalletSession> = .init()

                for blockchain in blockchains.values {
                    if let session = sessionsSubject.value[safe: blockchain.server] {
                        sessions[blockchain.server] = session
                    } else {
                        sessions[blockchain.server] = strongSelf.buildSession(blockchain: blockchain)
                    }
                }

                return sessions
            }.assign(to: \.value, on: sessionsSubject, ownership: .weak)
            .store(in: &cancelable)

        NotificationCenter.default.applicationState
            .receive(on: RunLoop.main)
            .sink { [sessionsSubject] state in
                switch state {
                case .didEnterBackground:
                    sessionsSubject.value.forEach { $0.value.blockNumberProvider.cancel() }
                case .willEnterForeground:
                    sessionsSubject.value.forEach { $0.value.blockNumberProvider.restart() }
                }
            }.store(in: &cancelable)
    }

    private func buildSession(blockchain: BlockchainProvider) -> WalletSession {
        let ercTokenProvider: TokenProviderType = TokenProvider(
            account: wallet,
            blockchainProvider: blockchain)

        let contractDataFetcher = ContractDataFetcher(
            wallet: wallet,
            ercTokenProvider: ercTokenProvider,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            reachability: reachability)

        let importToken = ImportToken(
            tokensDataStore: tokensDataStore,
            contractDataFetcher: contractDataFetcher,
            server: blockchain.server,
            reachability: reachability)

        let nftProvider = AlphaWalletNFTProvider(
            analytics: analytics,
            wallet: wallet,
            server: blockchain.server,
            config: config,
            storage: .storage(for: wallet))

        let tokenAdaptor = TokenAdaptor(
            assetDefinitionStore: assetDefinitionStore,
            eventsDataStore: eventsDataStore,
            wallet: wallet,
            nftProvider: nftProvider)

        let blockchainExplorer = buildBlockchainExplorer(server: blockchain.server, wallet: wallet, ercTokenProvider: ercTokenProvider)

        return WalletSession(
            account: wallet,
            server: blockchain.server,
            config: config,
            analytics: analytics,
            ercTokenProvider: ercTokenProvider,
            importToken: importToken,
            blockchainProvider: blockchain,
            nftProvider: nftProvider,
            tokenAdaptor: tokenAdaptor,
            blockchainExplorer: blockchainExplorer)
    }

    public func session(for server: RPCServer) -> WalletSession? {
        sessionsSubject.value[safe: server]
    }

    private func buildBlockchainExplorer(server: RPCServer, wallet: Wallet, ercTokenProvider: TokenProviderType) -> BlockchainExplorer {
        let transporter = apiTransporterFactory.transporter(server: server)

        switch server.transactionsSource {
        case .etherscan(let apiKey, let url):
            let transactionBuilder = TransactionBuilder(tokensDataStore: tokensDataStore, server: server, ercTokenProvider: ercTokenProvider)
            return EtherscanCompatibleBlockchainExplorer(server: server, transporter: transporter, transactionBuilder: transactionBuilder, baseUrl: url, apiKey: apiKey, analytics: analytics)
        case .blockscout(let apiKey, let url):
            let transactionBuilder = TransactionBuilder(tokensDataStore: tokensDataStore, server: server, ercTokenProvider: ercTokenProvider)
            return BlockscoutBlockchainExplorer(server: server, transporter: transporter, transactionBuilder: transactionBuilder, apiKey: apiKey, baseUrl: url, analytics: analytics)
        case .covalent(let apiKey):
            return CovalentBlockchainExplorer(server: server, apiKey: apiKey, transporter: transporter, analytics: analytics)
        case .oklink(let apiKey):
            let transactionBuilder = TransactionBuilder(tokensDataStore: tokensDataStore, server: server, ercTokenProvider: ercTokenProvider)
            return OklinkBlockchainExplorer(server: server, apiKey: apiKey, transporter: transporter, ercTokenProvider: ercTokenProvider, transactionBuilder: transactionBuilder, analytics: analytics)
        case .unknown:
            return FallbackBlockchainExplorer()
        }
    }
}

public class ApiTransporterFactory {
    private var transportes: [RPCServer: ApiTransporter] = [:]

    public init(transportes: [RPCServer: ApiTransporter] = [:]) {
        self.transportes = transportes
    }

    public func transporter(server: RPCServer) -> ApiTransporter {
        if let transporter = transportes[server] {
            return transporter
        } else {
            let policy: RetryPolicy

            switch server {
            case .goerli, .mumbai_testnet, .sepolia:
                //NOTE: goerli as well as mumbai_testnet and sepolia retrun 403 error code
                policy = ApiTransporterRetryPolicy(retryableHTTPStatusCodes: [429, 408, 500, 502, 503, 504, 403])
            case .xDai, .classic, .main, .callisto, .binance_smart_chain, .heco, .fantom, .avalanche, .polygon, .optimistic, .arbitrum, .palm, .klaytnCypress, .ioTeX, .cronosMainnet, .okx, .binance_smart_chain_testnet, .heco_testnet, .fantom_testnet, .avalanche_testnet, .cronosTestnet, .palmTestnet, .klaytnBaobabTestnet, .ioTeXTestnet, .optimismGoerli, .arbitrumGoerli, .custom:
                policy = ApiTransporterRetryPolicy()
            }

            let transporter = BaseApiTransporter(policy: policy)

            transportes[server] = transporter
            return transporter
        }
    }
}
