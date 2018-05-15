// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import Trust
import Foundation

class TicketAdaptorTest: XCTestCase {

    func testBundlesAreBrokenIntoContinousSeatRanges() {
        let date = Date()
        let tickets = [
            Ticket(id: "1", index: 1, city: "City", name: "Name", venue: "Venue", match: 1, date: date, seatId: 1, category: "1", countryA: "Team A", countryB: "Team B"),
            Ticket(id: "2", index: 2, city: "City", name: "Name", venue: "Venue", match: 1, date: date, seatId: 2, category: "1", countryA: "Team A", countryB: "Team B"),
            Ticket(id: "3", index: 3, city: "City", name: "Name", venue: "Venue", match: 1, date: date, seatId: 4, category: "1", countryA: "Team A", countryB: "Team B"),
        ]
        let bundles = TicketAdaptor(token: TokenObject()).bundle(tickets: tickets)
        XCTAssertEqual(bundles.count, 2)
    }
}
