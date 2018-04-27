//
//  Ticket.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

struct Ticket {
    let id: String
    let index: UInt16
    let city: String
    let name: String
    let venue: String
    let date: Date
    let seatId: Int
    let category: Int
    let countryA: String
    let countryB: String
    static var empty: Ticket {
        return Ticket(
                id: Constants.nullTicket,
                index: UInt16(0),
                city: "N/A",
                name: "FIFA WC",
                venue: "N/A",
                date: Date(),
                seatId: 0,
                category: 0,
                countryA: "N/A",
                countryB: "N/A"
        )
    }
}
