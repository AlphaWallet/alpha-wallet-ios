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
    
    //TODO change to bytes rather than hex
    //TODO configure language settings to be compatible with this
    func getFifaInfoForToken(tokenId tokenBytes32: BigUInt, lang: Int) -> FIFAInfo {
        //check if leading or trailing zeros
        var tokenId = MarketQueueHandler.bytesToHexa(tokenBytes32.serialize().bytes).substring(to: 32)
        if BigUInt(tokenId, radix: 16)! < 0 {
            tokenId = MarketQueueHandler.bytesToHexa(tokenBytes32.serialize().bytes).substring(from: 32)
        }
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
    
//    func getFifaInfoForTokenInBytes(tokenId tokenBytes32: BigUInt, lang: Int) -> FIFAInfo {
//        var tokenId = tokenBytes32.serialize().bytes
//        let token = filterLeadingOrTrailingZeros(tokenId)
//
//    }
//
//    func filterLeadingOrTrailingZeros(_ array: [UInt8]) -> [UInt8] {
//        var tokenId = array
//        var leadingToken = [UInt8]()
//        var trailingToken = [UInt8]()
//        for i in 0...(tokenId.count / 2) - 1 {
//            leadingToken.append(tokenId[i])
//        }
//        if BigUInt(Data(bytes: leadingToken)) <= 0 {
//            for i in (tokenId.count / 2)...tokenId.count - 1 {
//                trailingToken.append(tokenId[i])
//            }
//        } else {
//            tokenId = leadingToken
//        }
//        return tokenId
//    }
    
    func getLocale(attribute: String, lang: Int) -> String {
        let localeNumber = Int(attribute, radix: 16)!
        if let parsedLocale = xml["asset"]["fields"]["field"][0][0]["mapping"]["entity"][localeNumber]["name"][lang].text {
            return parsedLocale
        } else {
            return "N/A"
        }
    }

    func getVenue(attribute: String, lang: Int) -> String {
        let venueNumber = Int(attribute, radix: 16)!
        if let parsedVenue = xml["asset"]["fields"]["field"][1][0]["mapping"]["entity"][venueNumber]["name"][lang].text {
            return parsedVenue
        } else {
            return "N/A"
        }
    }
    
}
