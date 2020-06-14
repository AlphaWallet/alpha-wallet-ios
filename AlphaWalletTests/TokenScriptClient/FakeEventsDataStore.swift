// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet

class FakeEventsDataStore: EventsDataStoreProtocol {
    func add(events: [EventInstance], forTokenContract contract: AlphaWallet.Address) {
    }

    func deleteEvents(forTokenContract contract: AlphaWallet.Address) {
    }

    func getMatchingEvents(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> [EventInstance] {
        .init()
    }

    func getMatchingEventsSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> [EventInstance] {
        .init()
    }

    func subscribe(_ subscribe: @escaping (_ contract: AlphaWallet.Address) -> Void) {
    }
}
