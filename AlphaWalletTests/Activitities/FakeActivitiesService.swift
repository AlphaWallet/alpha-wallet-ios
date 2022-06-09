// Copyright © 2021 Stormbird PTE. LTD.

@testable import AlphaWallet
import Combine

class FakeActivitiesService: ActivitiesServiceType {
    var sessions: ServerDictionary<WalletSession> { .make() }
    
    var activitiesPublisher: AnyPublisher<[ActivitiesViewModel.MappedToDateActivityOrTransaction], Never> {
        Just([])
            .eraseToAnyPublisher()
    }
    var didUpdateActivityPublisher: AnyPublisher<Activity, Never> {
        Just(Activity())
            .eraseToAnyPublisher()
    }

    func start() {}
    func reinject(activity: Activity) {}
    func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType { self }
}
