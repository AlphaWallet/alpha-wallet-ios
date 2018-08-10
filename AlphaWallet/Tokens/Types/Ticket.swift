//
//  Ticket.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

struct Ticket {
    let id: String
    let index: UInt16
    var name: String
    let values: [String: AssetAttributeValue]

    var city: String {
        return values["locality"] as? String ?? "N/A"
    }

    var venue: String {
        return values["venue"] as? String ?? "N/A"
    }

    var match: Int {
        return values["match"] as? Int ?? 0
    }

    var date: GeneralisedTime {
        return values["time"] as? GeneralisedTime ?? .init()
    }

    var seatId: Int {
        return values["numero"] as? Int ?? 0
    }

    var category: String {
        return values["category"] as? String ?? "N/A"
    }

    var countryA: String {
        return values["countryA"] as? String ?? ""
    }

    var countryB: String {
        return values["countryB"] as? String ?? ""
    }

    static var empty: Ticket {
        return Ticket(
                id: Constants.nullTicket,
                index: 0,
                name: "FIFA WC",
                values: [
                    "locality": "N/A",
                    "venue": "N/A",
                    "match": 0,
                    "time": GeneralisedTime.init(),
                    "numero": 0,
                    "category": "N/A",
                    "countryA": "N/A",
                    "countryB": "N/A"
                ]
        )
    }
}
