//
//  ActivitiesPipeLine.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.08.2022.
//

import Foundation
import Combine

final class ActivitiesPipeLine: ActivitiesServiceType {
    private let config: Config
    private let wallet: Wallet
    private let localStore: LocalStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let sessionsProvider: SessionsProvider
    private let transactionDataStore: TransactionDataStore

    lazy private var eventsDataStore: NonActivityEventsDataStore = {
        return NonActivityMultiChainEventsDataStore(store: localStore.getOrCreateStore(forWallet: wallet))
    }()
    lazy private var eventsActivityDataStore: EventsActivityDataStoreProtocol = {
        return EventsActivityDataStore(store: localStore.getOrCreateStore(forWallet: wallet))
    }()
    private lazy var eventSourceCoordinatorForActivities: EventSourceCoordinatorForActivities? = {
        guard Features.default.isAvailable(.isActivityEnabled) else { return nil }
        return EventSourceCoordinatorForActivities(wallet: wallet, config: config, tokensDataStore: tokensDataStore, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsActivityDataStore)
    }()

    private let tokensDataStore: TokensDataStore

    private lazy var eventSourceCoordinator: EventSourceCoordinator = {
        EventSourceCoordinator(wallet: wallet, tokensDataStore: tokensDataStore, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, config: config)
    }()

    private lazy var activitiesSubService: ActivitiesServiceType = {
        return ActivitiesService(config: config, sessions: sessionsProvider.activeSessions, assetDefinitionStore: assetDefinitionStore, eventsActivityDataStore: eventsActivityDataStore, eventsDataStore: eventsDataStore, transactionDataStore: transactionDataStore, tokensDataStore: tokensDataStore)
    }()

    var activitiesPublisher: AnyPublisher<[ActivitiesViewModel.MappedToDateActivityOrTransaction], Never> {
        activitiesSubService.activitiesPublisher
    }

    var didUpdateActivityPublisher: AnyPublisher<Activity, Never> {
        activitiesSubService.didUpdateActivityPublisher
    }

    init(config: Config, wallet: Wallet, localStore: LocalStore, assetDefinitionStore: AssetDefinitionStore, transactionDataStore: TransactionDataStore, tokensDataStore: TokensDataStore, sessionsProvider: SessionsProvider) {
        self.config = config
        self.wallet = wallet
        self.localStore = localStore
        self.assetDefinitionStore = assetDefinitionStore
        self.transactionDataStore = transactionDataStore
        self.tokensDataStore = tokensDataStore
        self.sessionsProvider = sessionsProvider
    }

    func start() {
        //NOTE: need to figure out creating xml handlers, object creating takes a lot of resources
        eventSourceCoordinator.start()
        eventSourceCoordinatorForActivities?.start()

        activitiesSubService.start()
    }

    func reinject(activity: Activity) {
        activitiesSubService.reinject(activity: activity)
    }

    func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType {
        activitiesSubService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: transactionsFilterStrategy)
    }
}
