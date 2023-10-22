//
//  ActivitiesPipeLine.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.08.2022.
//

import Foundation
import Combine

public final class ActivitiesPipeLine: ActivitiesServiceType {
    private let config: Config
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let sessionsProvider: SessionsProvider
    private let transactionDataStore: TransactionDataStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let eventsActivityDataStore: EventsActivityDataStoreProtocol
    private lazy var eventSourceForActivities: EventSourceForActivities? = {
        guard Features.current.isAvailable(.isActivityEnabled) else { return nil }
        return EventSourceForActivities(
            wallet: wallet,
            config: config,
            tokensService: tokensService,
            assetDefinitionStore: assetDefinitionStore,
            eventsDataStore: eventsActivityDataStore,
            sessionsProvider: sessionsProvider)
    }()
    private let tokensService: TokensService
    private lazy var eventSource: EventSource = {
        EventSource(
            wallet: wallet,
            tokensService: tokensService,
            assetDefinitionStore: assetDefinitionStore,
            eventsDataStore: eventsDataStore,
            config: config,
            sessionsProvider: sessionsProvider)
    }()

    private lazy var activitiesSubService: ActivitiesServiceType = {
        return ActivitiesService(
            sessionsProvider: sessionsProvider,
            eventsActivityDataStore: eventsActivityDataStore,
            transactionDataStore: transactionDataStore,
            tokensService: tokensService)
    }()

    public var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> {
        activitiesSubService.activitiesPublisher
    }

    public var didUpdateActivityPublisher: AnyPublisher<Activity, Never> {
        activitiesSubService.didUpdateActivityPublisher
    }

    public init(config: Config,
                wallet: Wallet,
                assetDefinitionStore: AssetDefinitionStore,
                transactionDataStore: TransactionDataStore,
                tokensService: TokensService,
                sessionsProvider: SessionsProvider,
                eventsActivityDataStore: EventsActivityDataStoreProtocol,
                eventsDataStore: NonActivityEventsDataStore) {

        self.eventsActivityDataStore = eventsActivityDataStore
        self.eventsDataStore = eventsDataStore
        self.tokensService = tokensService
        self.config = config
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.transactionDataStore = transactionDataStore
        self.sessionsProvider = sessionsProvider
    }

    public func start() async {
        //NOTE: need to figure out creating xml handlers, object creating takes a lot of resources
        eventSource.start()
        eventSourceForActivities?.start()
        await activitiesSubService.start()
    }

    public func stop() async {
        await activitiesSubService.stop()
        eventSource.stop()
        eventSourceForActivities?.stop()
    }

    public func reinject(activity: Activity) async {
        await activitiesSubService.reinject(activity: activity)
    }

    public func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) async -> ActivitiesServiceType {
        return await activitiesSubService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: transactionsFilterStrategy)
    }
}
