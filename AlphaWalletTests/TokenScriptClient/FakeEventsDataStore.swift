// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit
@testable import AlphaWallet

class FakeEventsDataStore: EventsDataStoreProtocol {

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventInstance?> {
        return .value(nil)
    }

    func add(events: [EventInstanceValue], forTokenContract contract: AlphaWallet.Address) {
        //no-op
    }

    func deleteEvents(forTokenContract contract: AlphaWallet.Address) {
    }

    func getMatchingEvent(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, filterName: String, filterValue: String) -> EventInstance? {
        return nil
    }

    func subscribe(_ subscribe: @escaping (_ contract: AlphaWallet.Address) -> Void) {
    }

    func getLastMatchingEventSortedByBlockNumber(forContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String) -> Promise<EventInstanceValue?> {
        Promise { _ in }
    }
}
