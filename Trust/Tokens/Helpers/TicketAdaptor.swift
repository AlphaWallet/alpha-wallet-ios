//
//  BalanceHelper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import RealmSwift
import BigInt

class TicketAdaptor {

    public class func getTicketHolders(for token: TokenObject) -> [TicketHolder] {
        var ticketHolders: [TicketHolder] = []
        let balance = token.balance
        for (index, item) in balance.enumerated() {
            //id is the value of the bytes32 ticket
            let id = item.balance
            if id == "0x0000000000000000000000000000000000000000000000000000000000000000" { // if balance is 0, then skip
                continue
            }
            let ticket = getTicket(for: BigUInt(id.substring(from: 2), radix: 16)!, index: UInt16(index), in: token)
            if let item = ticketHolders.filter({ $0.zone == ticket.zone && $0.date == ticket.date && $0.category == ticket.category }).first {
                item.tickets.append(ticket)
            } else {
                let ticketHolder = getTicketHolder(for: ticket)
                ticketHolders.append(ticketHolder)
            }
        }
        return ticketHolders
    }

    //TODO pass lang into here
    private class func getTicket(for id: BigUInt, index: UInt16, in token: TokenObject) -> Ticket {
        return XMLHandler().getFifaInfoForTicket(tokenId: id, index: index)
    }

    private class func getTicketHolder(for ticket: Ticket) -> TicketHolder {
        return TicketHolder(
            tickets: [ticket],
            zone: ticket.zone,
            name: ticket.name,
            venue: ticket.venue,
            date: ticket.date,
            category: ticket.category,
            status: .available
        )
    }

}
