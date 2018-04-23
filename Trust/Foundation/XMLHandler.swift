//
//  XMLHandler.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import SwiftyXMLParser
import BigInt

struct FIFAInfo {
    let locality: String
    let venue: String
    let time: Int
    let countryA: String
    let countryB: String
    let match: Int
    let category: Int
    let number: Int
}

public class XMLHandler {

    private let xml = try! XML.parse(AssetDefinitionXML.assetDefinition)
    public let blankFIFAInfo = FIFAInfo(
            locality: "N/A",
            venue: "N/A",
            time: 0,
            countryA: "N/A",
            countryB: "N/A",
            match: 0,
            category: 0,
            number: 0
    )
    
    func getFifaInfoForToken(tokenId tokenBytes32: BigUInt) -> FIFAInfo {
        //check if leading or trailing zeros
        let tokenId = tokenBytes32
        if tokenId != 0 {
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
            return FIFAInfo(
                locality: location,
                venue: venue,
                time: time,
                countryA: String(data: Data(bytes: countryA), encoding: .utf8)!,
                countryB: String(data: Data(bytes: countryB), encoding: .utf8)!,
                match: match,
                category: category,
                number: number
            )
        }
        return self.blankFIFAInfo
    }

    func getLang() -> Int {
        let lang = Locale.preferredLanguages[0]
        var langNum = 0
        //english etc is often en-SG
        if lang.contains("en") {
            langNum = 1
        } else if lang.contains("zh") {
            langNum = 2
        } else if lang.contains("es") {
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
