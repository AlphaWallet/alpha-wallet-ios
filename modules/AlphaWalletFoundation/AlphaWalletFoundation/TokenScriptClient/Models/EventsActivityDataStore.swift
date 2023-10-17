// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import Combine

public protocol EventsActivityDataStoreProtocol {
    func recentEventsChangeset(servers: [RPCServer]) -> AnyPublisher<ChangeSet<[EventActivityInstance]>, Never>
    func getRecentEventsSortedByBlockNumber(for contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) async -> [EventActivityInstance]
    func getLastMatchingEventSortedByBlockNumber(for contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) async -> EventActivityInstance?
    func addOrUpdate(events: [EventActivityInstance])
}

public class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    private let store: RealmStore
    private var cancellables = Set<AnyCancellable>()

    public init(store: RealmStore) {
        self.store = store
    }

    public func recentEventsChangeset(servers: [RPCServer]) -> AnyPublisher<ChangeSet<[EventActivityInstance]>, Never> {
        let publisher = PassthroughSubject<ChangeSet<[EventActivityInstance]>, Never>()
        Task {
            //Let the app start up and load Wallet tab quickly
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await store.performSync { realm in
                realm.objects(EventActivity.self)
                        .filter(functional.chainIdPredicate(servers: servers))
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
                        }.sink { value in
                            publisher.send(value)
                        }.store(in: &self.cancellables)
            }
        }
        return publisher.eraseToAnyPublisher()
    }

    public func getRecentEventsSortedByBlockNumber(for contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) async -> [EventActivityInstance] {
        let predicate = EventsActivityDataStore.functional.matchingEventPredicate(for: contract, server: server, eventName: eventName, interpolatedFilter: interpolatedFilter)
        var eventActivities: [EventActivityInstance] = []
        await store.perform { realm in
            eventActivities = realm.objects(EventActivity.self)
                .filter(predicate)
                .sorted(byKeyPath: "blockNumber", ascending: false)
                .map { EventActivityInstance(event: $0) }
        }

        return eventActivities
    }

    public func getLastMatchingEventSortedByBlockNumber(for contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) async -> EventActivityInstance? {
        let predicate = Self.matchingEventPredicate(for: contract, tokenContract: tokenContract, server: server, eventName: eventName)
        var eventActivity: EventActivityInstance?
        await store.perform { realm in
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
        Task {
            await store.perform { realm in
                try? realm.safeWrite {
                    realm.add(eventsToSave, update: .all)
                }
            }
        }
    }

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

    static func matchingEventPredicate(for contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isContractMatchPredicate(contract: contract),
            isTokenContractMatchPredicate(contract: tokenContract),
            isChainIdMatchPredicate(server: server),
            isEventNameMatchPredicate(eventName: eventName),
        ])
    }
}

extension EventsActivityDataStore {
    enum functional {}
}

fileprivate extension EventsActivityDataStore.functional {
    static func chainIdPredicate(servers: [RPCServer]) -> NSPredicate {
        return NSPredicate(format: "chainId IN %@", servers.map { $0.chainID })
    }

    static func isFilterMatchPredicate(interpolatedFilter: String) -> NSPredicate {
        return NSPredicate(format: "filter = '\(interpolatedFilter)'")
    }

    static func matchingEventPredicate(for contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            EventsActivityDataStore.isContractMatchPredicate(contract: contract),
            EventsActivityDataStore.isChainIdMatchPredicate(server: server),
            EventsActivityDataStore.isEventNameMatchPredicate(eventName: eventName),
            isFilterMatchPredicate(interpolatedFilter: interpolatedFilter)
        ])
    }
}
