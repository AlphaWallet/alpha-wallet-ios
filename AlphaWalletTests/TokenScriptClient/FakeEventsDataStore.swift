// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Combine
import RealmSwift

@testable import AlphaWallet

class FakeEventsDataStore: NonActivityEventsDataStore {
    func recentEvents(forTokenContract tokenContract: AlphaWallet.Address) -> AnyPublisher<RealmCollectionChange<Results<EventInstance>>, Never> {
        fatalError()
    }

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventInstance?> {
        return .value(nil)
    }

    func add(events: [EventInstanceValue]) {
        //no-op
    }

    func deleteEvents(forTokenContract contract: AlphaWallet.Address) {
    }

    func getMatchingEvent(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> EventInstance? {
        return nil
    }

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventInstanceValue?> {
        Promise { _ in }
    }
}
