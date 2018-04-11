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
    let team: String
    let venue: String
    let time: Int
    let countryA: Int
    let countryB: Int
    let match: Int
    let category: Int
    let number: Int
}

public class XMLHandler {
    
    let xml = try! XML.parse(AssetDefinitionXML.assetDefinition)
    
    func getFifaInfoForToken(tokenId: String, lang: String) -> FIFAInfo {
        let locale = getLocale(attribute: tokenId.substring(to: 2), lang: lang)
        let team = getTeam(attribute: tokenId.substring(to: 8), lang: lang)
        let venue = getVenue(attribute: tokenId.substring(to: 6), lang: lang)
        let time = Int(tokenId.substring(with: Range((5, 12))), radix: 16)!
        let countryA = Int(tokenId.substring(with: Range(13, 19)), radix: 16)!
        let countryB = Int(tokenId.substring(with: Range(20, 26)), radix: 16)!
        let match = Int(tokenId.substring(with: Range(27, 29)), radix: 16)!
        let category = Int(tokenId.substring(with: Range(30, 32)), radix: 16)!
        let number = Int(tokenId.substring(from: 33), radix: 16)!
        return FIFAInfo
        (
                        locale: locale,
                        team: team,
                        venue: venue,
                        time: time,
                        countryA: countryA,
                        countryB: countryB,
                        match: match,
                        category: category,
                        number: number
        )
    }
    
    func getLocale(attribute: String, lang: String) -> String {
        let localeNumber = Int(attribute, radix: 16)!
        return xml["field"]["locality"]["mapping"]["entity"][localeNumber][lang]
    }
    
    func getVenue(attribute: String, lang: String) -> String {
        let venueNumber = Int(attribute, radix: 16)!
        return xml["field"]["venue"]["mapping"]["entity"][venueNumber][lang]
    }
    
}
