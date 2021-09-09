// Copyright © 2021 Stormbird PTE. LTD.

@testable import AlphaWallet

class FakeActivitiesService: ActivitiesServiceType {
    var sessions: ServerDictionary<WalletSession> { .make() }
    var subscribableViewModel: Subscribable<ActivitiesViewModel> { .init(nil) }
    var subscribableUpdatedActivity: Subscribable<Activity> { .init(nil) }

    func stop() {}
    func reinject(activity: Activity) {}
    func copy(activitiesFilterStrategy: ActivitiesFilterStrategy, transactionsFilterStrategy: TransactionsFilterStrategy) -> ActivitiesServiceType { self }
}
