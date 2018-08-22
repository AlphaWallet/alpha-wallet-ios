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
        switch token.type {
        case .ether, .erc20, .erc875:
            return getNonCryptoKittyTicketHolders()
        case .erc721:
            let tokenType = CryptoKittyHandling(address: token.address)
            switch tokenType {
            case .cryptoKitty:
                return getCryptoKittyTicketHolders()
            case .otherNonFungibleToken:
                return getNonCryptoKittyTicketHolders()
            }
        }
    }

    private func getNonCryptoKittyTicketHolders() -> [TokenHolder] {
        let balance = token.balance
        var tickets = [Token]()
        for (index, item) in balance.enumerated() {
            //id is the value of the bytes32 ticket
            let id = item.balance
            guard isNonZeroBalance(id) else { continue }
            if let ticketInt = BigUInt(id.drop0x, radix: 16) {
                let ticket = getTicket(for: ticketInt, index: UInt16(index), in: token)
                tickets.append(ticket)
            }
        }

        return bundle(tickets: tickets)
    }

    private func getCryptoKittyTicketHolders() -> [TokenHolder] {
        let balance = token.balance
        var tickets = [Token]()
        for (index, item) in balance.enumerated() {
            let jsonString = item.balance
            if let ticket = getTicketForCryptoKitty(forJSONString: jsonString, in: token) {
                tickets.append(ticket)
            }
        }

        return bundle(tickets: tickets)
    }

    func bundle(tickets: [Token]) -> [TokenHolder] {
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
        return bundles.sorted {
            let d0 = $0.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            let d1 = $1.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            return d0 < d1
        }
    }

    //If sequential or have the same seat number, add them together
    ///e.g 21, 22, 25 is broken up into 2 bundles: 21-22 and 25.
    ///e.g 21, 21, 22, 25 is broken up into 2 bundles: (21,21-22) and 25.
    private func breakBundlesFurtherToHaveContinuousSeatRange(tickets: [Token]) -> [[Token]] {
        let tickets = tickets.sorted {
            let s0 = $0.values["numero"] as? Int ?? 0
            let s1 = $1.values["numero"] as? Int ?? 0
            return s0 <= s1
        }
        return tickets.reduce([[Token]]()) { results, ticket in
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
    private func groupTicketsByFields(tickets: [Token]) -> Dictionary<String, [Token]>.Values {
        var dictionary = [String: [Token]]()
        for each in tickets {
            let city = each.values["locality"] as? String ?? "N/A"
            let venue = each.values["venue"] as? String ?? "N/A"
            let date = each.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            let countryA = each.values["countryA"] as? String ?? ""
            let countryB = each.values["countryB"] as? String ?? ""
            let match = each.values["match"] as? Int ?? 0
            let category = each.values["category"] as? String ?? "N/A"

            let hash = "\(city),\(venue),\(date),\(countryA),\(countryB),\(match),\(category)"
            var group = dictionary[hash] ?? []
            group.append(each)
            dictionary[hash] = group
        }
        return dictionary.values
    }

    //TODO pass lang into here
    private func getTicket(for id: BigUInt, index: UInt16, in token: TokenObject) -> Token {
        return XMLHandler(contract: token.contract).getFifaInfoForTicket(tokenId: id, index: index)
    }

    private func getTicketForCryptoKitty(forJSONString jsonString: String, in token: TokenObject) -> Token? {
        guard let data = jsonString.data(using: .utf8), let cat = try? JSONDecoder().decode(CryptoKitty.self, from: data) else { return nil }
        var values = [String: AssetAttributeValue]()
        values["tokenId"] = cat.tokenId
        values["description"] = cat.description
        values["imageUrl"] = cat.imageUrl
        values["thumbnailUrl"] = cat.thumbnailUrl
        values["externalLink"] = cat.externalLink
        values["traits"] = cat.traits
        return Token(
                id: BigUInt(cat.tokenId)!,
                index: 0,
                name: "name",
                values: values
        )
    }

    private func getTicketHolder(for tickets: [Token]) -> TokenHolder {
        return TokenHolder(
                tickets: tickets,
                status: .available,
                contractAddress: token.contract
        )
    }

}

extension Token {
    //TODO Convenience-only. (Look for references). Should remove once we generalize things further and not hardcode the use of seatId
    var seatId: Int {
        return values["numero"] as? Int ?? 0
    }
}
