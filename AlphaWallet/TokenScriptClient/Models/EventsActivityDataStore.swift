// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import PromiseKit
import Combine

protocol EventsActivityDataStoreProtocol {
    var recentEventsPublisher: AnyPublisher<RealmCollectionChange<Results<EventActivity>>, Never> { get }

    func getRecentEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> Results<EventActivity>
    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventActivityInstance?>
    func add(events: [EventActivityInstance])
}

class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    //For performance. Fetching and displaying 10k activities stalls the app for a few seconds. We just keep it simple, no pagination. Pagination is complicated because we have to handle re-fetching of activities, updates as well as blending with transactions
    static let numberOfActivitiesToUse = 100

    private let realm: Realm

    init(realm: Realm) {
        self.realm = realm
    }

    var recentEventsPublisher: AnyPublisher<RealmCollectionChange<Results<EventActivity>>, Never> {
        return realm.objects(EventActivity.self)
            .sorted(byKeyPath: "date", ascending: false)
            .changesetPublisher
            .eraseToAnyPublisher()
    }

    func getRecentEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, server: RPCServer, eventName: String, interpolatedFilter: String) -> Results<EventActivity> {
        let predicate = EventsActivityDataStore
            .functional
            .matchingEventPredicate(forContract: contract, server: server, eventName: eventName, interpolatedFilter: interpolatedFilter)

        return realm.objects(EventActivity.self)
            .filter(predicate)
            .sorted(byKeyPath: "blockNumber", ascending: false)
    }

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventActivityInstance?> {

        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = EventsActivityDataStore
                    .functional
                    .matchingEventPredicate(forContract: contract, tokenContract: tokenContract, server: server, eventName: eventName)

                let objects = strongSelf.realm.objects(EventActivity.self)
                    .filter(predicate)
                    .sorted(byKeyPath: "blockNumber")
                    .last
                    .map { EventActivityInstance(event: $0) }

                seal.fulfill(objects)
            }
        }
    }

    private func delete<S: Sequence>(events: S) where S.Element: EventActivity {
        try? realm.write {
            realm.delete(events)
        }
    }

    func add(events: [EventActivityInstance]) {
        guard !events.isEmpty else { return }
        let eventsToSave = events.map { EventActivity(value: $0) }

        realm.beginWrite()
        realm.add(eventsToSave, update: .all)
        try? realm.commitWrite()
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
