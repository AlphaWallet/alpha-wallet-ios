// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift

protocol EventsActivityDataStoreProtocol {
    func add(events: [EventActivity], forTokenContract contract: AlphaWallet.Address)
    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> [EventActivity]
    func getEvents(forContract contract: AlphaWallet.Address, forEventName eventName: String, filter: String, server: RPCServer) -> [EventActivity]
    func getRecentEvents() -> [EventActivity]
}

class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    //For performance. Fetching and displaying 10k activities stalls the app for a few seconds. We just keep it simple, no pagination. Pagination is complicated because we have to handle re-fetching of activities, updates as well as blending with transactions
    static let numberOfActivitiesToUse = 1000

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

    func getRecentEvents() -> [EventActivity] {
        return Array(realm.objects(EventActivity.self)
                .sorted(byKeyPath: "date", ascending: false)
                .prefix(Self.numberOfActivitiesToUse)
        )
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
