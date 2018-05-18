//
//  TicketHolder.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

class TicketHolder {
    enum TicketHolderStatus {
        case available, sold, redeemed, forSale, transferred
    }

    var tickets: [Ticket]
    var city: String { return tickets[0].city }
    var name: String { return tickets[0].name }
    var venue: String { return tickets[0].venue }
    var match: Int { return tickets[0].match }
    var date: Date { return tickets[0].date }
    var category: String { return tickets[0].category }
    var countryA: String { return tickets[0].countryA }
    var countryB: String { return tickets[0].countryB }
    var timeZoneIdentifier: String? { return tickets[0].timeZoneIdentifier }
    var status: TicketHolderStatus
    var isSelected = false
    var areDetailsVisible = false

    init(tickets: [Ticket], status: TicketHolderStatus) {
        self.tickets = tickets
        self.status = status
    }

    var seatRange: String {
        let seatIds = tickets.map { $0.seatId }
        if seatIds.count == 1 {
            return seatIds.first!.toString()
        }
        return seatIds.min()!.toString() + "-" + seatIds.max()!.toString()
    }

    var count: Int {
        return tickets.count
    }

    var indices: [UInt16] {
        return tickets.map { $0.index }
    }
}
