// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import PromiseKit

protocol EventsActivityDataStoreProtocol {
    var recentEventsSubscribable: Subscribable<Void> { get }
    func removeSubscription(subscription: Subscribable<Void>)

    func getRecentEvents() -> Promise<[EventActivity]>
    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventActivityInstance?>
    func add(events: [EventActivityInstance], forTokenContract contract: AlphaWallet.Address) -> Promise<Void>
}

class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    //For performance. Fetching and displaying 10k activities stalls the app for a few seconds. We just keep it simple, no pagination. Pagination is complicated because we have to handle re-fetching of activities, updates as well as blending with transactions
    static let numberOfActivitiesToUse = 100

    private let realm: Realm
    private let queue: DispatchQueue

    init(realm: Realm, queue: DispatchQueue) {
        self.realm = realm
        self.queue = queue
    }

    private var cachedRecentEventsSubscribable: [Subscribable<Void>: NotificationToken] = [:]
    //NOTE: we are need only fact that we got events,
    //its easier way to determiene that events got updated
    var recentEventsSubscribable: Subscribable<Void> {
        let notifier = Subscribable<Void>(nil)
        let recentEvents = realm.objects(EventActivity.self)
            .sorted(byKeyPath: "date", ascending: false)

        let subscription = recentEvents.observe(on: queue) { _ in
            self.queue.async {
                notifier.value = ()
            }
        }

        cachedRecentEventsSubscribable[notifier] = subscription

        return notifier
    }

    func removeSubscription(subscription: Subscribable<Void>) {
        cachedRecentEventsSubscribable[subscription] = nil
    }

    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise <EventActivityInstance?> {

        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                let objects = strongSelf.realm.objects(EventActivity.self)
                    .filter("contract = '\(contract.eip55String)'")
                    .filter("tokenContract = '\(tokenContract.eip55String)'")
                    .filter("chainId = \(server.chainID)")
                    .filter("eventName = '\(eventName)'")
                    .sorted(byKeyPath: "blockNumber")
                    .last
                    .map { EventActivityInstance(event: $0) }

                seal.fulfill(objects)
            }
        }
    }

    func getRecentEvents() -> Promise<[EventActivity]> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                let values = Array(strongSelf.realm.objects(EventActivity.self)
                    .sorted(byKeyPath: "date", ascending: false)
                    .prefix(Self.numberOfActivitiesToUse))

                seal.fulfill(values)
            }
        }
    }

    private func delete<S: Sequence>(events: S) where S.Element: EventActivity {
        try? realm.write {
            realm.delete(events)
        }
    }

    func add(events: [EventActivityInstance], forTokenContract contract: AlphaWallet.Address) -> Promise<Void> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                if events.isEmpty {
                    seal.fulfill(())
                } else {
                    let realm = strongSelf.realm
                    let eventsToSave = events.map { EventActivity(value: $0) }

                    do {
                        realm.beginWrite()
                        realm.add(eventsToSave, update: .all)
                        try realm.commitWrite()

                        seal.fulfill(())
                    } catch {
                        seal.reject(error)
                    }
                }
            }
        }
    }
}
