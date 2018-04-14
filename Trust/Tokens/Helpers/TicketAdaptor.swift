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
            if let item = ticketHolders.filter({ $0.zone == ticket.zone && $0.date == ticket.date }).first {
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
        let fifaInfo = XMLHandler().getFifaInfoForToken(tokenId: id, lang: 1)
        let zone = fifaInfo.locale
        let name: String
        if token.address.eip55String == Constants.fifaContractAddress {
            name = token.title
        } else {
            name = "FIFA WC 2018"
        }
        let venue = fifaInfo.locale
        let seatId = fifaInfo.number
        let date = Date(timeIntervalSince1970: TimeInterval(fifaInfo.time)) //Date.init(string: fifaInfo.time, format: "dd MMM yyyy")
        return Ticket(
            id: MarketQueueHandler.bytesToHexa(id.serialize().bytes),
            index: index,
            zone: zone,
            name: name,
            venue: venue,
            date: date,
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
