// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import Trust
import Foundation

class TicketAdaptorTest: XCTestCase {

    func testBundlesAreBrokenIntoContinuousSeatRanges() {
        let date = GeneralisedTime()
        let tickets = [
            Ticket(id: "1", index: 1, name: "Name", values: ["city": "City", "venue": "Venue", "match": 1, "time": date, "numero": 1, "category": "1", "countryA": "Team A", "countryB": "Team B"]),
            Ticket(id: "2", index: 2, name: "Name", values: ["city": "City", "venue": "Venue", "match": 1, "time": date, "numero": 2, "category": "1", "countryA": "Team A", "countryB": "Team B"]),
            Ticket(id: "3", index: 3, name: "Name", values: ["city": "City", "venue": "Venue", "match": 1, "time": date, "numero": 4, "category": "1", "countryA": "Team A", "countryB": "Team B"]),
        ]
        let bundles = TokenAdaptor(token: TokenObject()).bundle(tickets: tickets)
        XCTAssertEqual(bundles.count, 2)
    }

    func testBundlesGroupIdenticalSeatIDsTogether() {
        let date = GeneralisedTime()
        let tickets = [
            Ticket(id: "1", index: 1, name: "Name", values: ["city": "City", "venue": "Venue", "match": 1, "time": date, "numero": 1, "category": "1", "countryA": "Team A", "countryB": "Team B"]),
            Ticket(id: "2", index: 2, name: "Name", values: ["city": "City", "venue": "Venue", "match": 1, "time": date, "numero": 2, "category": "1", "countryA": "Team A", "countryB": "Team B"]),
            Ticket(id: "3", index: 3, name: "Name", values: ["city": "City", "venue": "Venue", "match": 1, "time": date, "numero": 4, "category": "1", "countryA": "Team A", "countryB": "Team B"]),
            Ticket(id: "4", index: 4, name: "Name", values: ["city": "City", "venue": "Venue", "match": 1, "time": date, "numero": 2, "category": "1", "countryA": "Team A", "countryB": "Team B"]),
        ]
        let bundles = TokenAdaptor(token: TokenObject()).bundle(tickets: tickets)
        XCTAssertEqual(bundles.count, 2)
    }

}
