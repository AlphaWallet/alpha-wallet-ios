// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift 
import Combine 

protocol NonActivityEventsDataStore {
    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> EventInstance?
    func add(events: [EventInstanceValue])
    func deleteEvents(forTokenContract contract: AlphaWallet.Address)
    func getMatchingEvent(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> EventInstance?
    func recentEvents(forTokenContract tokenContract: AlphaWallet.Address) -> AnyPublisher<ChangeSet<[EventInstance]>, Never>
}

class NonActivityMultiChainEventsDataStore: NonActivityEventsDataStore {
    private let store: RealmStore
    private let queue = DispatchQueue(label: "com.NonActivityEventsDataStore.UpdateQueue")

    init(store: RealmStore) {
        self.store = store
    }

    func getMatchingEvent(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> EventInstance? {
        let predicate = NonActivityMultiChainEventsDataStore
            .functional
            .matchingEventPredicate(forContract: contract, tokenContract: tokenContract, server: server, eventName: eventName, filterName: filterName, filterValue: filterValue)

        var event: EventInstance?
        store.performSync { realm in
            event = realm.objects(EventInstance.self)
                .filter(predicate)
                .toArray()
                .first
        }
        return event
    }

    func deleteEvents(forTokenContract contract: AlphaWallet.Address) {
        store.performSync { realm in
            try? realm.safeWrite {
                let events = realm.objects(EventInstance.self)
                    .filter("tokenContract = '\(contract.eip55String)'")
                realm.delete(events)
            }
        }
    }

    func recentEvents(forTokenContract tokenContract: AlphaWallet.Address) -> AnyPublisher<ChangeSet<[EventInstance]>, Never> {
        var publisher: AnyPublisher<ChangeSet<[EventInstance]>, Never>!
        store.performSync { realm in
            publisher = realm.objects(EventInstance.self)
                .filter("tokenContract = '\(tokenContract.eip55String)'")
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

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> EventInstance? {
        let predicate = NonActivityMultiChainEventsDataStore
            .functional
            .matchingEventPredicate(forContract: contract, tokenContract: tokenContract, server: server, eventName: eventName)

        var event: EventInstance?
        store.performSync { realm in
            event = realm.objects(EventInstance.self)
                .filter(predicate)
                .sorted(byKeyPath: "blockNumber")
                .toArray()
                .last
        }

        return event
    }

    func add(events: [EventInstanceValue]) {
        guard !events.isEmpty else { return }
        let eventsToSave = events.map { EventInstance(event: $0) }

        store.performSync { realm in
            try? realm.safeWrite {
                realm.add(eventsToSave, update: .all)
            }
        }
    }
}

extension NonActivityMultiChainEventsDataStore {
    enum functional {}
}

extension NonActivityMultiChainEventsDataStore.functional {

    static func isFilterMatchPredicate(filterName: String, filterValue: String) -> NSPredicate {
        return NSPredicate(format: "filter = '\(filterName)=\(filterValue)'")
    }

    static func matchingEventPredicate(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            EventsActivityDataStore.functional.isContractMatchPredicate(contract: contract),
            EventsActivityDataStore.functional.isChainIdMatchPredicate(server: server),
            EventsActivityDataStore.functional.isTokenContractMatchPredicate(contract: tokenContract),
            EventsActivityDataStore.functional.isEventNameMatchPredicate(eventName: eventName),
            isFilterMatchPredicate(filterName: filterName, filterValue: filterValue)
        ])
    }

    static func matchingEventPredicate(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> NSPredicate {
        EventsActivityDataStore.functional.matchingEventPredicate(forContract: contract, tokenContract: tokenContract, server: server, eventName: eventName)
    }
}

