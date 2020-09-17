// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift

protocol EventsActivityDataStoreProtocol {
    func add(events: [EventActivity], forTokenContract contract: AlphaWallet.Address)
    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> [EventActivity]
    func getEvents(forContract contract: AlphaWallet.Address, forEventName eventName: String, filter: String, server: RPCServer) -> [EventActivity]
}

class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    private let realm: Realm

    init(realm: Realm) {
        self.realm = realm
    }

    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> [EventActivity] {
        Array(realm.objects(EventActivity.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("tokenContract = '\(tokenContract.eip55String)'")
                .filter("chainId = \(server.chainID)")
                .filter("eventName = '\(eventName)'")
                .sorted(byKeyPath: "blockNumber"))
    }

    func getEvents(forContract contract: AlphaWallet.Address, forEventName eventName: String, filter: String, server: RPCServer) -> [EventActivity] {
        Array(realm.objects(EventActivity.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("chainId = \(server.chainID)")
                .filter("eventName = '\(eventName)'")
                .filter("filter = '\(filter)'"))
    }

    private func delete<S: Sequence>(events: S) where S.Element: EventActivity {
        try? realm.write {
            realm.delete(events)
        }
    }

    func add(events: [EventActivity], forTokenContract contract: AlphaWallet.Address) {
        guard !events.isEmpty else { return }
        try! realm.write {
            for each in events {
                realm.add(each, update: .all)
            }
        }
    }
}
