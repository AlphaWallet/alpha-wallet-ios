//
//  WalletDependencies.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 26.04.2023.
//

import Foundation

public protocol WalletDependenciesProvidable: AnyObject {
    func walletDependencies(walletAddress: AlphaWallet.Address) -> WalletDependencies?
}

public struct WalletDependencies {
    public let activitiesPipeLine: ActivitiesPipeLine
    public let transactionsDataStore: TransactionDataStore
    public let tokensDataStore: TokensDataStore
    public let tokensService: TokensService
    public let pipeline: TokensProcessingPipeline
    public let fetcher: WalletBalanceFetcher
    public let sessionsProvider: SessionsProvider
    public let eventsDataStore: NonActivityEventsDataStore
    public let transactionsService: TransactionsService
    
    public init(activitiesPipeLine: ActivitiesPipeLine,
                transactionsDataStore: TransactionDataStore,
                tokensDataStore: TokensDataStore,
                tokensService: TokensService,
                pipeline: TokensProcessingPipeline,
                fetcher: WalletBalanceFetcher,
                sessionsProvider: SessionsProvider,
                eventsDataStore: NonActivityEventsDataStore,
                transactionsService: TransactionsService) {

        self.transactionsService = transactionsService
        self.activitiesPipeLine = activitiesPipeLine
        self.transactionsDataStore = transactionsDataStore
        self.tokensDataStore = tokensDataStore
        self.tokensService = tokensService
        self.pipeline = pipeline
        self.fetcher = fetcher
        self.sessionsProvider = sessionsProvider
        self.eventsDataStore = eventsDataStore
    }
}
