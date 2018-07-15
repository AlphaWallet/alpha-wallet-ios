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

class TokenAdaptor {
    var token: TokenObject
    init(token: TokenObject) {
        self.token = token
    }

    public func getTicketHolders() -> [TokenHolder] {
        let balance = token.balance
        var tickets = [Ticket]()
        for (index, item) in balance.enumerated() {
            //id is the value of the bytes32 ticket
            let id = item.balance
            if id == Constants.nullTicket { // if balance is 0, then skip
                continue
            }
            if let ticketInt = BigUInt(id.drop0x, radix: 16) {
                let ticket = getTicket(for: ticketInt, index: UInt16(index), in: token)
                tickets.append(ticket)
            }
        }

        return bundle(tickets: tickets)
    }

    func bundle(tickets: [Ticket]) -> [TokenHolder] {
        switch token.type {
        case .ether, .erc20, .erc875:
            break
        case .erc721:
            return tickets.map { getTicketHolder(for: [$0]) }
        }
        var ticketHolders: [TokenHolder] = []
        let groups = groupTicketsByFields(tickets: tickets)
        for each in groups {
            let results = breakBundlesFurtherToHaveContinuousSeatRange(tickets: each)
            for tickets in results {
                ticketHolders.append(getTicketHolder(for: tickets))
            }
        }
        ticketHolders = sortBundlesUpcomingFirst(bundles: ticketHolders)
        return ticketHolders
    }

    private func sortBundlesUpcomingFirst(bundles: [TokenHolder]) -> [TokenHolder] {
        return bundles.sorted { $0.date < $1.date }
    }

    //If sequential or have the same seat number, add them together
    ///e.g 21, 22, 25 is broken up into 2 bundles: 21-22 and 25.
    ///e.g 21, 21, 22, 25 is broken up into 2 bundles: (21,21-22) and 25.
    private func breakBundlesFurtherToHaveContinuousSeatRange(tickets: [Ticket]) -> [[Ticket]] {
        let tickets = tickets.sorted { $0.seatId <= $1.seatId }
        return tickets.reduce([[Ticket]]()) { results, ticket in
            var results = results
            if var previousRange = results.last, let previousTicket = previousRange.last, (previousTicket.seatId + 1 == ticket.seatId || previousTicket.seatId == ticket.seatId) {
                previousRange.append(ticket)
                let _ = results.popLast()
                results.append(previousRange)
            } else {
                results.append([ticket])
            }
            return results
        }
    }

    ///Group by the properties used in the hash. We abuse a dictionary to help with grouping
    private func groupTicketsByFields(tickets: [Ticket]) -> Dictionary<String, [Ticket]>.Values {
        var dictionary = [String: [Ticket]]()
        for each in tickets {
            let hash = "\(each.city),\(each.venue),\(each.date),\(each.countryA),\(each.countryB),\(each.match),\(each.category)"
            var group = dictionary[hash] ?? []
            group.append(each)
            dictionary[hash] = group
        }
        return dictionary.values
    }

    //TODO pass lang into here
    private func getTicket(for id: BigUInt, index: UInt16, in token: TokenObject) -> Ticket {
        return XMLHandler(contract: token.contract).getFifaInfoForTicket(tokenId: id, index: index)
    }

    private func getTicketHolder(for tickets: [Ticket]) -> TokenHolder {
        return TokenHolder(
                tickets: tickets,
                status: .available,
                contractAddress: token.contract
        )
    }

}
