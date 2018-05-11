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

    private let xml = try! XML.parse(AssetDefinitionXML.assetDefinition)

    func getFifaInfoForTicket(tokenId tokenBytes32: BigUInt, index: UInt16) -> Ticket {
        //check if leading or trailing zeros
        let tokenId = tokenBytes32
        guard tokenId != 0 else { return .empty }
        let lang = getLang()
        let tokenHex = MarketQueueHandler.bytesToHexa(tokenBytes32.serialize().bytes)
        let location = getLocality(attribute: tokenHex.substring(to: 2), lang: lang)
        let venue = getVenue(attribute: tokenHex.substring(with: Range(uncheckedBounds: (2, 4))), lang: lang)
        let time = Int(tokenHex.substring(with: Range(uncheckedBounds: (4, 12))), radix: 16)!
        //translatable to ascii
        let countryA = tokenHex.substring(with: Range(uncheckedBounds: (12, 18))).hexa2Bytes
        let countryB = tokenHex.substring(with: Range(uncheckedBounds: (18, 24))).hexa2Bytes
        let match = Int(tokenHex.substring(with: Range(uncheckedBounds: (24, 26))), radix: 16)!
        let category = Int(tokenHex.substring(with: Range(uncheckedBounds: (26, 28))), radix: 16)!
        let number = Int(tokenHex.substring(with: Range(uncheckedBounds: (28, 32))), radix: 16)!

        return Ticket(
                id: MarketQueueHandler.bytesToHexa(tokenId.serialize().array),
                index: index,
                city: location,
                name: getName(lang: lang),
                venue: venue,
                match: match,
                date: Date(timeIntervalSince1970: TimeInterval(time)),
                seatId: number,
                category: category,
                countryA: String(data: Data(bytes: countryA), encoding: .utf8)!,
                countryB: String(data: Data(bytes: countryB), encoding: .utf8)!
        )
    }

    func getAddressFromXML(chainId: Int) -> Address {
        var contract = 0
        if chainId != 1 {
            contract = 1 //ropsten
        }
        if let address = xml["asset"]["contract"]["address"][contract].text {
            return Address(string: address)!
        }
        return Address(string: "0x000000000000000000000000000000000000dEaD")!
    }

    func getName(lang: Int) -> String {
        if let name = xml["asset"]["contract"]["name"][lang].text {
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
        //TODO find out why - 1
        let locality = Int(attribute, radix: 16)! - 1
        if let parsedLocality = xml["asset"]["fields"]["field"][0][0]["mapping"]["entity"][locality]["name"][lang].text {
            return parsedLocality
        }
        return "N/A"
    }

    func getVenue(attribute: String, lang: Int) -> String {
        let venueNumber = Int(attribute, radix: 16)!
        if let parsedVenue = xml["asset"]["fields"]["field"][1][0]["mapping"]["entity"][venueNumber]["name"][lang].text {
            return parsedVenue
        }
        return "N/A"
    }

}
