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
    var store: RealmStore { get }
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
        public let store: RealmStore
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

        let store: RealmStore = .storage(for: wallet)
        let tokensDataStore: TokensDataStore = MultipleChainsTokensDataStore(store: store, servers: config.enabledServers)
        let eventsDataStore: NonActivityEventsDataStore = NonActivityMultiChainEventsDataStore(store: store)
        let transactionsDataStore = TransactionDataStore(store: store)

        let sessionsProvider: SessionsProvider = .init(config: config, analytics: analytics)

        let importToken = ImportToken(sessionProvider: sessionsProvider, wallet: wallet, tokensDataStore: tokensDataStore, assetDefinitionStore: assetDefinitionStore, analytics: analytics)

        let tokensService = AlphaWalletTokensService(sessionsProvider: sessionsProvider, tokensDataStore: tokensDataStore, analytics: analytics, importToken: importToken, transactionsStorage: transactionsDataStore, nftProvider: nftProvider, assetDefinitionStore: assetDefinitionStore)
        let pipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(wallet: wallet, tokensService: tokensService, coinTickersFetcher: coinTickersFetcher, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)

        let fetcher = WalletBalanceFetcher(wallet: wallet, tokensService: pipeline)

        let dependency: WalletDependency = Dependencies(store: store, transactionsDataStore: transactionsDataStore, importToken: importToken, tokensService: tokensService, pipeline: pipeline, fetcher: fetcher, sessionsProvider: sessionsProvider, eventsDataStore: eventsDataStore)

        walletDependencies[wallet] = dependency

        return dependency
    }

    public func destroy(for wallet: Wallet) {
        walletDependencies[wallet] = nil
    }
}
