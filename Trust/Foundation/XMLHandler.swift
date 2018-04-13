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
    let locale: String
    let venue: String
    let time: Int
    let countryA: String
    let countryB: String
    let match: Int
    let category: Int
    let number: Int
}

/**
 langs:
 0 = ru
 1 = en
 2 = zh
 3 = es
 */

public class XMLHandler {
    
    private let xml = try! XML.parse(AssetDefinitionXML.assetDefinition)
    
    //TODO make this take bytes instead of hex string
    func getFifaInfoForToken(tokenId tokenBytes32: BigUInt, lang: Int) -> FIFAInfo {
        var tokenId = MarketQueueHandler.bytesToHexa(tokenBytes32.serialize().bytes)
        tokenId = tokenId.substring(to: 32) //slicing off the trailing zeros
        let locale = getLocale(attribute: tokenId.substring(to: 2), lang: lang)
        let venue = getVenue(attribute: tokenId.substring(with: Range(uncheckedBounds: (2, 4))), lang: lang)
        let time = Int(tokenId.substring(with: Range(uncheckedBounds: (5, 12))), radix: 16)!
        //translatable to ascii
        let countryA = tokenId.substring(with: Range(uncheckedBounds: (12, 18))).hexa2Bytes
        let countryB = tokenId.substring(with: Range(uncheckedBounds: (18, 24))).hexa2Bytes
        let match = Int(tokenId.substring(with: Range(uncheckedBounds: (24, 26))), radix: 16)!
        let category = Int(tokenId.substring(with: Range(uncheckedBounds: (26, 28))), radix: 16)!
        let number = Int(tokenId.substring(from: 28), radix: 16)!
        return FIFAInfo(
                        locale: locale,
                        venue: venue,
                        time: time,
                        countryA: String(data: Data(bytes: countryA), encoding: .utf8)!,
                        countryB: String(data: Data(bytes: countryB), encoding: .utf8)!,
                        match: match,
                        category: category,
                        number: number
        )
    }
    
    func getLocale(attribute: String, lang: Int) -> String {
        let localeNumber = Int(attribute, radix: 16)!
        return xml["asset"]["fields"]["field"][0][0]["mapping"]["entity"][localeNumber]["name"][lang].text!
    }
    
    func getVenue(attribute: String, lang: Int) -> String {
        let venueNumber = Int(attribute, radix: 16)!
        return xml["asset"]["fields"]["field"][1][0]["mapping"]["entity"][venueNumber]["name"][lang].text!
    }
    
}
