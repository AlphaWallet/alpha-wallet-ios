// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import PromiseKit

protocol EventsActivityDataStoreProtocol {
    func getRecentEvents() -> [EventActivity]
    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise <EventActivityInstance?>
    func add(events: [EventActivityInstance], forTokenContract contract: AlphaWallet.Address) -> Promise<Void>
}

class EventsActivityDataStore: EventsActivityDataStoreProtocol {
    //For performance. Fetching and displaying 10k activities stalls the app for a few seconds. We just keep it simple, no pagination. Pagination is complicated because we have to handle re-fetching of activities, updates as well as blending with transactions
    static let numberOfActivitiesToUse = 100

    private let realm: Realm

    init(realm: Realm) {
        self.realm = realm
    }

    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise <EventActivityInstance?> {

        return Promise { seal in
            let objects = realm.threadSafe.objects(EventActivity.self)
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

    func getEvents(forContract contract: AlphaWallet.Address, forEventName eventName: String, filter: String, server: RPCServer) -> [EventActivity] {
        Array(realm.objects(EventActivity.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("chainId = \(server.chainID)")
                .filter("eventName = '\(eventName)'")
                .filter("filter = '\(filter)'"))
    }

    func getRecentEvents() -> [EventActivity] {
        return Array(realm.threadSafe.objects(EventActivity.self)
                .sorted(byKeyPath: "date", ascending: false)
                .prefix(Self.numberOfActivitiesToUse)
        )
    }

    private func delete<S: Sequence>(events: S) where S.Element: EventActivity {
        try? realm.write {
            realm.delete(events)
        }
    }

    func add(events: [EventActivityInstance], forTokenContract contract: AlphaWallet.Address) -> Promise<Void> {
        if events.isEmpty {
            return .value(())
        } else {
            return Promise { seal in
                let eventsToSave = events.map { EventActivity(value: $0) }

                do {
                    let realm = self.realm.threadSafe
                    try realm.write {
                        realm.add(eventsToSave, update: .all)

                        seal.fulfill(())
                    }
                } catch {
                    seal.reject(error)
                }
            }
        }
    }
}
