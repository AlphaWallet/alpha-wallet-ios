//
//  TicketHolder.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

enum TicketHolderStatus {
    case available, sold, redeemed, forSale, transferred
}

class TicketHolder {
    var tickets: [Ticket]
    var city: String
    var name: String
    var venue: String
    var match: Int
    var date: Date
    let category: Int
    let countryA: String
    let countryB: String
    var status: TicketHolderStatus
    var isSelected = false
    var areDetailsVisible = false

    init(
            tickets: [Ticket],
            city: String,
            name: String,
            venue: String,
            match: Int,
            date: Date,
            category: Int,
            countryA: String,
            countryB: String,
            status: TicketHolderStatus
    ) {
        self.tickets = tickets
        self.city = city
        self.name = name
        self.venue = venue
        self.match = match
        self.date = date
        self.category = category
        self.countryA = countryA
        self.countryB = countryB
        self.status = status
    }

    var seatRange: String {
        let seatIds = tickets.map { $0.seatId }
        if seatIds.count == 1 {
            return seatIds.first!.toString()
        }
        return seatIds.min()!.toString() + "-" + seatIds.max()!.toString()
    }

    //TODO this should be a numeric type
    var ticketCount: String {
        return tickets.count.toString()
    }

    var ticketIndices: [UInt16] {
        return tickets.map { $0.index }
    }
}
