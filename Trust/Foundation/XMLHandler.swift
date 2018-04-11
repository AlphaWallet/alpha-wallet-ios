//
//  XMLHandler.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import SwiftyXMLParser

struct FIFAInfo {
    let locale: String
    let venue: String
    let time: Int
    let countryA: Int
    let countryB: Int
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
    
    let xml = try! XML.parse(AssetDefinitionXML.assetDefinition)
    
    func getFifaInfoForToken(tokenId: String, lang: Int) -> FIFAInfo {
        let locale = getLocale(attribute: tokenId.substring(to: 2), lang: lang)
        let venue = getVenue(attribute: tokenId.substring(with: Range(uncheckedBounds: (2, 4))), lang: lang)
        let time = Int(tokenId.substring(with: Range(uncheckedBounds: (5, 12))), radix: 16)!
        let countryA = Int(tokenId.substring(with: Range(uncheckedBounds: (13, 18))), radix: 16)!
        let countryB = Int(tokenId.substring(with: Range(uncheckedBounds: (19, 24))), radix: 16)!
        let match = Int(tokenId.substring(with: Range(uncheckedBounds: (25, 26))), radix: 16)!
        let category = Int(tokenId.substring(with: Range(uncheckedBounds: (27, 29))), radix: 16)!
        let number = Int(tokenId.substring(from: 30), radix: 16)!
        return FIFAInfo(
                        locale: locale,
                        venue: venue,
                        time: time,
                        countryA: countryA,
                        countryB: countryB,
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
