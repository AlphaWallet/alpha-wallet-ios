// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift

protocol EventsDataStoreProtocol {
    func add(events: [EventInstance], forTokenContract contract: AlphaWallet.Address)
    func deleteEvents(forTokenContract contract: AlphaWallet.Address)
    func getMatchingEvents(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> [EventInstance]
    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> [EventInstance]
    func subscribe(_ subscribe: @escaping (_ contract: AlphaWallet.Address) -> Void)
}

//TODO rename to indicate it's for instances, not activity
class EventsDataStore: EventsDataStoreProtocol {
    private let realm: Realm
    private var subscribers: [(AlphaWallet.Address) -> Void] = []

    init(realm: Realm) {
        self.realm = realm
    }

    func subscribe(_ subscribe: @escaping (_ contract: AlphaWallet.Address) -> Void) {
        subscribers.append(subscribe)
    }

    private func triggerSubscribers(forContract contract: AlphaWallet.Address) {
        subscribers.forEach { $0(contract) }
    }

    func getMatchingEvents(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> [EventInstance] {
        Array(realm.objects(EventInstance.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("tokenContract = '\(tokenContract.eip55String)'")
                .filter("chainId = \(server.chainID)")
                .filter("eventName = '\(eventName)'")
                //Filter stored as string, so we do a string comparison
                .filter("filter = '\(filterName)=\(filterValue)'"))
    }

    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> [EventInstance] {
        Array(realm.objects(EventInstance.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("tokenContract = '\(tokenContract.eip55String)'")
                .filter("chainId = \(server.chainID)")
                .filter("eventName = '\(eventName)'")
                .sorted(byKeyPath: "blockNumber"))
    }

    func deleteEvents(forTokenContract contract: AlphaWallet.Address) {
        let events = getEvents(forTokenContract: contract)
        delete(events: events)
    }

    private func getEvents(forTokenContract tokenContract: AlphaWallet.Address) -> Results<EventInstance> {
        realm.objects(EventInstance.self)
                .filter("tokenContract = '\(tokenContract.eip55String)'")
    }

    private func delete<S: Sequence>(events: S) where S.Element: EventInstance {
        try? realm.write {
            realm.delete(events)
        }
    }

    func add(events: [EventInstance], forTokenContract contract: AlphaWallet.Address) {
        guard !events.isEmpty else { return }
        try! realm.write {
            for each in events {
                realm.add(each, update: .all)
            }
        }
        triggerSubscribers(forContract: contract)
    }
}
