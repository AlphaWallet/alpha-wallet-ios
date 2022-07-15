//
//  WalletDependencyContainer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

import Foundation

protocol WalletDependencyContainer {
    func destroy(for wallet: Wallet)
    func makeDependencies(for wallet: Wallet) -> WalletDependency
}

protocol WalletDependency {
    var tokensDataStore: TokensDataStore { get }
    var transactionsStorage: TransactionDataStore { get }
    var importToken: ImportToken { get }
    var tokensService: TokensService { get }
    var pipeline: TokensProcessingPipeline { get }
    var fetcher: WalletBalanceFetcher { get }
    var sessionsProvider: SessionsProvider { get }
}

class WalletComponentsFactory: WalletDependencyContainer {
    let analytics: AnalyticsServiceType
    let nftProvider: NFTProvider
    let assetDefinitionStore: AssetDefinitionStore
    let store: LocalStore
    let coinTickersFetcher: CoinTickersFetcher
    let config: Config

    private var walletDependencies: [Wallet: WalletDependency] = [:]

    struct Dependencies: WalletDependency {
        let tokensDataStore: TokensDataStore
        let transactionsStorage: TransactionDataStore
        let importToken: ImportToken
        let tokensService: TokensService
        let pipeline: TokensProcessingPipeline
        let fetcher: WalletBalanceFetcher
        let sessionsProvider: SessionsProvider
        let eventsDataStore: NonActivityEventsDataStore
    }

    init(analytics: AnalyticsServiceType, nftProvider: NFTProvider, assetDefinitionStore: AssetDefinitionStore, store: LocalStore, coinTickersFetcher: CoinTickersFetcher, config: Config) {
        self.analytics = analytics
        self.nftProvider = nftProvider
        self.assetDefinitionStore = assetDefinitionStore
        self.store = store
        self.coinTickersFetcher = coinTickersFetcher
        self.config = config
    }

    func makeDependencies(for wallet: Wallet) -> WalletDependency {
        if let dep = walletDependencies[wallet] { return dep }

        let localStore = store.getOrCreateStore(forWallet: wallet)
        let tokensDataStore: TokensDataStore = MultipleChainsTokensDataStore(store: localStore, servers: config.enabledServers)
        let eventsDataStore: NonActivityEventsDataStore = NonActivityMultiChainEventsDataStore(store: localStore)
        let transactionsStorage = TransactionDataStore(store: localStore)

        let sessionsProvider: SessionsProvider = .init(config: config, analytics: analytics)

        let importToken = ImportToken(sessionProvider: sessionsProvider, wallet: wallet, tokensDataStore: tokensDataStore, assetDefinitionStore: assetDefinitionStore, analytics: analytics)

        let tokensService: TokensService = AlphaWalletTokensService(sessionsProvider: sessionsProvider, tokensDataStore: tokensDataStore, analytics: analytics, importToken: importToken, transactionsStorage: transactionsStorage, nftProvider: nftProvider, assetDefinitionStore: assetDefinitionStore)
        let pipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(wallet: wallet, tokensService: tokensService, coinTickersFetcher: coinTickersFetcher, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)

        let fetcher = WalletBalanceFetcher(wallet: wallet, service: pipeline)

        let dependency: WalletDependency = Dependencies(tokensDataStore: tokensDataStore, transactionsStorage: transactionsStorage, importToken: importToken, tokensService: tokensService, pipeline: pipeline, fetcher: fetcher, sessionsProvider: sessionsProvider, eventsDataStore: eventsDataStore)

        walletDependencies[wallet] = dependency

        return dependency
    }

    func destroy(for wallet: Wallet) {
        walletDependencies[wallet] = nil
    }
}
