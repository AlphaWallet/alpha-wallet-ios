// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import Combine

public protocol EventsActivityDataStoreProtocol {
    var recentEventsChangeset: AnyPublisher<ChangeSet<[EventActivityInstance]>, Never> { get }

    func getRecentEventsSortedByBlockNumber(for contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> [EventActivityInstance]
    func getLastMatchingEventSortedByBlockNumber(for contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> EventActivityInstance?
    func addOrUpdate(events: [EventActivityInstance])
}

public class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    private let store: RealmStore
    
    public init(store: RealmStore) {
        self.store = store
    }

    public var recentEventsChangeset: AnyPublisher<ChangeSet<[EventActivityInstance]>, Never> {
        var publisher: AnyPublisher<ChangeSet<[EventActivityInstance]>, Never>!
        store.performSync { realm in
            publisher = realm.objects(EventActivity.self)
                .sorted(byKeyPath: "date", ascending: false)
                .changesetPublisher
                .freeze()
                .receive(on: DispatchQueue.global())
                .map { change in
                    switch change {
                    case .initial(let eventActivities):
                        return .initial(Array(eventActivities.map { EventActivityInstance(event: $0) }))
                    case .update(let eventActivities, let deletions, let insertions, let modifications):
                        return .update(Array(eventActivities.map { EventActivityInstance(event: $0) }), deletions: deletions, insertions: insertions, modifications: modifications)
                    case .error(let error):
                        return .error(error)
                    }
                }
                .eraseToAnyPublisher()
        }
        return publisher
    }

    public func getRecentEventsSortedByBlockNumber(for contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> [EventActivityInstance] {
        let predicate = EventsActivityDataStore
            .functional
            .matchingEventPredicate(for: contract, server: server, eventName: eventName, interpolatedFilter: interpolatedFilter)

        var eventActivities: [EventActivityInstance] = []
        store.performSync { realm in
            eventActivities = realm.objects(EventActivity.self)
                .filter(predicate)
                .sorted(byKeyPath: "blockNumber", ascending: false)
                .map { EventActivityInstance(event: $0) }
        }

        return eventActivities
    }

    public func getLastMatchingEventSortedByBlockNumber(for contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> EventActivityInstance? {
        let predicate = EventsActivityDataStore
            .functional
            .matchingEventPredicate(for: contract, tokenContract: tokenContract, server: server, eventName: eventName)

        var eventActivity: EventActivityInstance?
        store.performSync { realm in
            eventActivity = realm.objects(EventActivity.self)
                .filter(predicate)
                .sorted(byKeyPath: "blockNumber")
                .last
                .flatMap { EventActivityInstance(event: $0) }
        }

        return eventActivity
    }

    public func addOrUpdate(events: [EventActivityInstance]) {
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

    static func matchingEventPredicate(for contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isContractMatchPredicate(contract: contract),
            isChainIdMatchPredicate(server: server),
            isEventNameMatchPredicate(eventName: eventName),
            isFilterMatchPredicate(interpolatedFilter: interpolatedFilter)
        ])
    }

    static func matchingEventPredicate(for contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isContractMatchPredicate(contract: contract),
            isTokenContractMatchPredicate(contract: tokenContract),
            isChainIdMatchPredicate(server: server),
            isEventNameMatchPredicate(eventName: eventName),
        ])
    }
}
