// Copyright © 2021 Stormbird PTE. LTD.

@testable import AlphaWallet
import Combine
import AlphaWalletFoundation

class FakeActivitiesService: ActivitiesServiceType {
    let sessionsProvider: SessionsProvider = FakeSessionsProvider(servers: [.main])
    
    var activitiesPublisher: AnyPublisher<[ActivityCollection.MappedToDateActivityOrTransaction], Never> {
        Just([])
            .eraseToAnyPublisher()
    }
    var didUpdateActivityPublisher: AnyPublisher<Activity, Never> {
        Just(Activity())
            .eraseToAnyPublisher()
    }

    func start() {}
    func stop() {}
    func reinject(activity: Activity) {}
    func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType { self }
}
