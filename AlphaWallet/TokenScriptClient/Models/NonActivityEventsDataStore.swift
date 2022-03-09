// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift 
import Combine
import PromiseKit

protocol NonActivityEventsDataStore {
    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventInstanceValue?>
    func add(events: [EventInstanceValue])
    func deleteEvents(forTokenContract contract: AlphaWallet.Address)
    func getMatchingEvent(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> EventInstance?
    func recentEvents(forTokenContract tokenContract: AlphaWallet.Address) -> AnyPublisher<RealmCollectionChange<Results<EventInstance>>, Never>
}

class NonActivityMultiChainEventsDataStore: NonActivityEventsDataStore {
    private let realm: Realm

    init(realm: Realm) {
        self.realm = realm
    }

    func getMatchingEvent(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> EventInstance? {
        let predicate = NonActivityMultiChainEventsDataStore
            .functional
            .matchingEventPredicate(forContract: contract, tokenContract: tokenContract, server: server, eventName: eventName, filterName: filterName, filterValue: filterValue)

        return realm.objects(EventInstance.self)
            .filter(predicate)
            .first
    }

    func deleteEvents(forTokenContract contract: AlphaWallet.Address) {
        let events = realm.objects(EventInstance.self)
            .filter("tokenContract = '\(contract.eip55String)'")
        delete(events: events)
    }

    func recentEvents(forTokenContract tokenContract: AlphaWallet.Address) -> AnyPublisher<RealmCollectionChange<Results<EventInstance>>, Never> {
        return realm.objects(EventInstance.self)
            .filter("tokenContract = '\(tokenContract.eip55String)'")
            .changesetPublisher
            .eraseToAnyPublisher()
    }

    private func delete<S: Sequence>(events: S) where S.Element: EventInstance {
        try? realm.write {
            realm.delete(events)
        }
    }

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventInstanceValue?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = NonActivityMultiChainEventsDataStore
                    .functional
                    .matchingEventPredicate(forContract: contract, tokenContract: tokenContract, server: server, eventName: eventName)

                let event = Array(strongSelf.realm.objects(EventInstance.self)
                    .filter(predicate)
                    .sorted(byKeyPath: "blockNumber"))
                    .map { EventInstanceValue(event: $0) }
                    .last

                seal.fulfill(event)
            }
        }
    }

    func add(events: [EventInstanceValue]) {
        guard !events.isEmpty else { return }
        let eventsToSave = events.map { EventInstance(event: $0) }

        realm.beginWrite()
        realm.add(eventsToSave, update: .all)
        try? realm.commitWrite()
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

