// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit
@testable import AlphaWallet

class FakeEventsDataStore: EventsDataStoreProtocol {

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventInstance?> {
        return .value(nil)
    }

    func add(events: [EventInstanceValue], forTokenContract contract: AlphaWallet.Address) -> Promise<Void> {
        return .init()
    }

    func deleteEvents(forTokenContract contract: AlphaWallet.Address) {
    }

    func getMatchingEvents(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> [EventInstance] {
        .init()
    }

    func subscribe(_ subscribe: @escaping (_ contract: AlphaWallet.Address) -> Void) {
    }
}
