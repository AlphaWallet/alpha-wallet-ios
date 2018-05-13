//
//  XMLHandler.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import SwiftyXMLParser
import BigInt
import TrustKeystore

public class XMLHandler {

    private let xml = try! XML.parse(AssetDefinitionXML().assetDefinitionString)

    //TODO remove once parser is properly dynamic
    public static func parseTicket(ticket: String) -> String
    {
        let no0xTicket = ticket.substring(from: 2)
        let firstHalfOfTicket = no0xTicket.substring(to: 32)
        let bigUIntFirstHalf = BigUInt(firstHalfOfTicket, radix: 16)
        if bigUIntFirstHalf == 0 {
            return no0xTicket
        }
        //if first 16 bytes are not empty then cut it in half
        //else return with padded 0's
        return no0xTicket.substring(from: 32)
    }

    func getFifaInfoForTicket(tokenId tokenBytes32: BigUInt, index: UInt16) -> Ticket {
        //check if leading or trailing zeros
        let tokenId = tokenBytes32
        guard tokenId != 0 else { return .empty }
        let lang = getLang()
        let tokenHex = MarketQueueHandler.bytesToHexa(tokenBytes32.serialize().bytes)
        let location = getLocality(attribute: tokenHex.substring(to: 2), lang: lang)
        let venue = getVenue(attribute: tokenHex.substring(with: Range(uncheckedBounds: (2, 4))), lang: lang)
        let time = Int(tokenHex.substring(with: Range(uncheckedBounds: (4, 12))), radix: 16)
                ?? Int(Date.tomorrow.timeIntervalSince1970.rounded(to: 0))
        //translatable to ascii
        let countryA = tokenHex.substring(with: Range(uncheckedBounds: (12, 18))).hexa2Bytes
        let countryB = tokenHex.substring(with: Range(uncheckedBounds: (18, 24))).hexa2Bytes
        let countryAString = String(data: Data(bytes: countryA), encoding: .utf8) ?? "TBD"
        let countryBString = String(data: Data(bytes: countryB), encoding: .utf8) ?? "TBD"
        let match = Int(tokenHex.substring(with: Range(uncheckedBounds: (24, 26))), radix: 16) ?? 0
        let category = Int(tokenHex.substring(with: Range(uncheckedBounds: (26, 28))), radix: 16) ?? 0
        let number = Int(tokenHex.substring(with: Range(uncheckedBounds: (28, 32))), radix: 16) ?? 0
        //TODO derive/extract from XML
        let timeZoneIdentifier = Constants.eventTimeZone

        return Ticket(
                id: MarketQueueHandler.bytesToHexa(tokenId.serialize().array),
                index: index,
                city: location,
                name: getName(lang: lang),
                venue: venue,
                match: match,
                date: Date(timeIntervalSince1970: TimeInterval(time)),
                seatId: number,
                category: getCategory(category, lang: lang),
                countryA: countryAString,
                countryB: countryBString,
                timeZoneIdentifier: timeZoneIdentifier
        )
    }

    func getAddressFromXML(server: RPCServer) -> Address {
        if server == .ropsten {
            if let address = xml["asset"]["contract"][0]["address"][1].text {
                return Address(string: address)!
            }
        } else {
            if let address = xml["asset"]["contract"][0]["address"][0].text {
                return Address(string: address)!
            }
        }
        return Address(string: Constants.ticketContractAddressRopsten)!
    }

    func getName(lang: Int) -> String {
        if let name = xml["asset"]["contract"][0]["name"][lang].text {
            return name
        }
        return "N/A"
    }
    
    func getLang() -> Int {
        let lang = Locale.preferredLanguages[0]
        var langNum = 0
        //english etc is often en-SG
        if lang.hasPrefix("en") {
            langNum = 1
        } else if lang.hasPrefix("zh") {
            langNum = 2
        } else if lang.hasPrefix("es") {
            langNum = 3
        }
        return langNum
    }

    func getLocality(attribute: String, lang: Int) -> String {
        //entity keys start at 1 but xml finder starts at 0, hence -1
        if let locality = Int(attribute, radix: 16) {
            guard locality != 0 else { return "N/A" }
            if let parsedLocality = xml["asset"]["fields"]["field"][0][0]["mapping"]["entity"][locality - 1]["name"][lang].text {
                return parsedLocality
            }
        }
        return "N/A"
    }
    
    func getCategory(_ cat: Int, lang: Int) -> String {
        guard cat != 0 else { return "N/A" }
        if let category = xml["asset"]["fields"]["field"][6][0]["mapping"]["entity"][cat - 1]["name"][lang].text {
            return category
        }
        return "N/A"
    }

    func getVenue(attribute: String, lang: Int) -> String {
        if let venueNumber = Int(attribute, radix: 16) {
            guard venueNumber != 0 else { return "N/A" }
            if let parsedVenue = xml["asset"]["fields"]["field"][1][0]["mapping"]["entity"][venueNumber - 1]["name"][lang].text {
                return parsedVenue
            }
        }
        return "N/A"
    }

}
