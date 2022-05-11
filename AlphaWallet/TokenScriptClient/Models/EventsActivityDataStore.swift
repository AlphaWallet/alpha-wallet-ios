// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import Combine

protocol EventsActivityDataStoreProtocol {
    var recentEventsPublisher: AnyPublisher<ChangeSet<[EventActivity]>, Never> { get }

    func getRecentEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> [EventActivity]
    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> EventActivity?
    func add(events: [EventActivityInstance])
}

class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    private let store: RealmStore
    private let queue = DispatchQueue(label: "com.NonActivityEventsDataStore.UpdateQueue")
    
    init(store: RealmStore) {
        self.store = store
    }

    var recentEventsPublisher: AnyPublisher<ChangeSet<[EventActivity]>, Never> {
        var publisher: AnyPublisher<ChangeSet<[EventActivity]>, Never>!
        store.performSync { realm in
            publisher = realm.objects(EventActivity.self)
                .sorted(byKeyPath: "date", ascending: false)
                .changesetPublisher
                .subscribe(on: queue)
                .map { change in
                    switch change {
                    case .initial(let eventActivities):
                        return .initial(eventActivities.toArray())
                    case .update(let eventActivities, let deletions, let insertions, let modifications):
                        return .update(eventActivities.toArray(), deletions: deletions, insertions: insertions, modifications: modifications)
                    case .error(let error):
                        return .error(error)
                    }
                }
                .eraseToAnyPublisher()
        }
        return publisher
    }

    func getRecentEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> [EventActivity] {
        let predicate = EventsActivityDataStore
            .functional
            .matchingEventPredicate(forContract: contract, server: server, eventName: eventName, interpolatedFilter: interpolatedFilter)

        var eventActivities: [EventActivity] = []
        store.performSync { realm in
            eventActivities = realm.objects(EventActivity.self)
                .filter(predicate)
                .sorted(byKeyPath: "blockNumber", ascending: false)
                .toArray()
        }

        return eventActivities
    }

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> EventActivity? {
        let predicate = EventsActivityDataStore
            .functional
            .matchingEventPredicate(forContract: contract, tokenContract: tokenContract, server: server, eventName: eventName)

        var eventActivity: EventActivity?
        store.performSync { realm in
            eventActivity = realm.objects(EventActivity.self)
                    .filter(predicate)
                    .sorted(byKeyPath: "blockNumber")
                    .toArray()
                    .last
        }

        return eventActivity
    }

    func add(events: [EventActivityInstance]) {
        guard !events.isEmpty else { return }
        let eventsToSave = events.map { EventActivity(value: $0) }
        store.performSync { realm in
            try? realm.safeWrite {
                realm.add(eventsToSave, update: .all)
            }
        }
    }
}

extension EventsActivityDataStore {
    enum functional {}
}

extension EventsActivityDataStore.functional {

    static func isContractMatchPredicate(contract: AlphaWallet.Address) -> NSPredicate {
        return NSPredicate(format: "contract = '\(contract.eip55String)'")
    }

    static func isTokenContractMatchPredicate(contract: AlphaWallet.Address) -> NSPredicate {
        return NSPredicate(format: "tokenContract = '\(contract.eip55String)'")
    }

    static func isChainIdMatchPredicate(server: RPCServer) -> NSPredicate {
        return NSPredicate(format: "chainId = \(server.chainID)")
    }

    static func isEventNameMatchPredicate(eventName: String) -> NSPredicate {
        return NSPredicate(format: "eventName = '\(eventName)'")
    }

    static func isFilterMatchPredicate(interpolatedFilter: String) -> NSPredicate {
        return NSPredicate(format: "filter = '\(interpolatedFilter)'")
    }

    static func matchingEventPredicate(forContract contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isContractMatchPredicate(contract: contract),
            isChainIdMatchPredicate(server: server),
            isEventNameMatchPredicate(eventName: eventName),
            isFilterMatchPredicate(interpolatedFilter: interpolatedFilter)
        ])
    }

    static func matchingEventPredicate(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isContractMatchPredicate(contract: contract),
            isTokenContractMatchPredicate(contract: tokenContract),
            isChainIdMatchPredicate(server: server),
            isEventNameMatchPredicate(eventName: eventName),
        ])
    }
}
