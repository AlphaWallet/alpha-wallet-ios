//
//  BalanceHelper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import RealmSwift

class TicketAdaptor {

    public class func getTicketHolders(for token: TokenObject) -> [TicketHolder] {
        var ticketHolders: [TicketHolder] = []
        let balance = token.balance
        for (index, item) in balance.enumerated() {
            let id = UInt16(item.balance)
            if id == 0 { // if balance is 0, then skip
                continue
            }
            let ticket = getTicket(for: id, index: UInt16(index), in: token)
            if let item = ticketHolders.filter({ $0.zone == ticket.zone && $0.date == ticket.date }).first {
                item.tickets.append(ticket)
            } else {
                let ticketHolder = getTicketHolder(for: ticket)
                ticketHolders.append(ticketHolder)
            }
        }
        return ticketHolders
    }

    private class func getTicket(for id: UInt16, index: UInt16, in token: TokenObject) -> Ticket {
        let zone = TicketDecode.getZone(Int(id))
        let name: String
        if token.address.eip55String == Constants.fifaContractAddress {
            name = token.title
        } else {
            name = TicketDecode.getName()
        }
        let venue = TicketDecode.getVenue(Int(id))
        let seatId = TicketDecode.getSeatIdInt(Int(id))
        let date = Date.init(string: TicketDecode.getDate(Int(id)), format: "dd MMM yyyy")
        return Ticket(
            id: id,
            index: index,
            zone: zone,
            name: name,
            venue: venue,
            date: date!,
            seatId: seatId
        )
    }

    private class func getTicketHolder(for ticket: Ticket) -> TicketHolder {
        return TicketHolder(
            tickets: [ticket],
            zone: ticket.zone,
            name: ticket.name,
            venue: ticket.venue,
            date: ticket.date,
            status: .available
        )
    }

}
