//
//  WalletDependencyContainer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

import Foundation

public protocol WalletDependencyContainer {
    func destroy(for wallet: Wallet)
    func makeDependencies(for wallet: Wallet) -> WalletDependency
}

public protocol WalletDependency {
    var activitiesPipeLine: ActivitiesPipeLine { get }
    var transactionsDataStore: TransactionDataStore { get }
    var importToken: ImportToken { get }
    var tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable & TokensServiceTests { get }
    var pipeline: TokensProcessingPipeline { get }
    var fetcher: WalletBalanceFetcher { get }
    var sessionsProvider: SessionsProvider { get }
}

public class WalletComponentsFactory: WalletDependencyContainer {
    public let analytics: AnalyticsServiceType
    public let nftProvider: NFTProvider
    public let assetDefinitionStore: AssetDefinitionStore
    public let coinTickersFetcher: CoinTickersFetcher
    public let config: Config
    
    private var walletDependencies: [Wallet: WalletDependency] = [:]

    public struct Dependencies: WalletDependency {
        public let activitiesPipeLine: ActivitiesPipeLine
        public let transactionsDataStore: TransactionDataStore
        public let importToken: ImportToken
        public let tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable & TokensServiceTests
        public let pipeline: TokensProcessingPipeline
        public let fetcher: WalletBalanceFetcher
        public let sessionsProvider: SessionsProvider
        public let eventsDataStore: NonActivityEventsDataStore
    }

    public init(analytics: AnalyticsServiceType, nftProvider: NFTProvider, assetDefinitionStore: AssetDefinitionStore, coinTickersFetcher: CoinTickersFetcher, config: Config) {
        self.analytics = analytics
        self.nftProvider = nftProvider
        self.assetDefinitionStore = assetDefinitionStore
        self.coinTickersFetcher = coinTickersFetcher
        self.config = config
    }

    public func makeDependencies(for wallet: Wallet) -> WalletDependency {
        if let dep = walletDependencies[wallet] { return dep }

        let tokensDataStore: TokensDataStore = MultipleChainsTokensDataStore(store: .storage(for: wallet), servers: config.enabledServers)
        let eventsDataStore: NonActivityEventsDataStore = NonActivityMultiChainEventsDataStore(store: .storage(for: wallet))
        let transactionsDataStore: TransactionDataStore = TransactionDataStore(store: .storage(for: wallet))
        let eventsActivityDataStore: EventsActivityDataStoreProtocol = EventsActivityDataStore(store: .storage(for: wallet))

        let sessionsProvider: SessionsProvider = .init(config: config, analytics: analytics)
        sessionsProvider.start(wallet: wallet)

        let importToken = ImportToken(sessionProvider: sessionsProvider, tokensDataStore: tokensDataStore, assetDefinitionStore: assetDefinitionStore, analytics: analytics)

        let tokensService = AlphaWalletTokensService(sessionsProvider: sessionsProvider, tokensDataStore: tokensDataStore, analytics: analytics, importToken: importToken, transactionsStorage: transactionsDataStore, nftProvider: nftProvider, assetDefinitionStore: assetDefinitionStore)
        let pipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(wallet: wallet, tokensService: tokensService, coinTickersFetcher: coinTickersFetcher, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        pipeline.start()

        let fetcher = WalletBalanceFetcher(wallet: wallet, tokensService: pipeline)
        fetcher.start()

        let activitiesPipeLine = ActivitiesPipeLine(config: config, wallet: wallet, assetDefinitionStore: assetDefinitionStore, transactionDataStore: transactionsDataStore, tokensService: tokensService, sessionsProvider: sessionsProvider, eventsActivityDataStore: eventsActivityDataStore, eventsDataStore: eventsDataStore, analytics: analytics)

        let dependency: WalletDependency = Dependencies(activitiesPipeLine: activitiesPipeLine, transactionsDataStore: transactionsDataStore, importToken: importToken, tokensService: tokensService, pipeline: pipeline, fetcher: fetcher, sessionsProvider: sessionsProvider, eventsDataStore: eventsDataStore)

        walletDependencies[wallet] = dependency

        return dependency
    }

    public func destroy(for wallet: Wallet) {
        walletDependencies[wallet] = nil
    }
}
