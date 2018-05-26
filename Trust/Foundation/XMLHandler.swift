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

//  Case by types e.g. enumeration
//  DIctionary class for non fungible token
//  TODO handle flexible attribute names e.g. asset, contract
//  Handle generics for multiple asset defintions

//kkk need to move?
extension XML.Accessor {
    func getElement(attributeName: String, attributeValue: String) -> XML.Element? {
        switch self {
        case .singleElement(let element):
            let attributeIsCorrect = element.attributes[attributeName] == attributeValue
            if attributeIsCorrect {
                return element
            } else {
                return nil
            }
        case .sequence(let elements):
            return elements.first {
                $0.attributes[attributeName] == attributeValue
            }
        case .failure:
            return nil
        }
    }

    func getElementWithKeyAttribute(equals value: String) -> XML.Element? {
        return getElement(attributeName: "key", attributeValue: value)
    }

    func getElementWithLangAttribute(equals value: String) -> XML.Element? {
        return getElement(attributeName: "lang", attributeValue: value)
    }
}

public class XMLHandler {

    private let xml = try! XML.parse(AssetDefinitionXML().assetDefinitionString)

    //TODO remove once parser is properly dynamic
    public static func parseTicket(ticket: String) -> String {
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

        let locationField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "locality")!
        //kkk should check for nil and handle rather than default to any value in this class. It should be returning a reasonable default already
        let locality: String = FieldType(field: locationField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? ""

        let venueField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "locality")!
        let venue: String = FieldType(field: venueField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? ""

        let timeField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "time")!
        let time: Date = FieldType(field: timeField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? Date()

        let countryAField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "countryA")!
        let countryA: String = FieldType(field: countryAField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? ""

        let countryBField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "countryB")!
        let countryB: String = FieldType(field: countryBField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? ""

        let matchField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "match")!
        let match: Int = FieldType(field: matchField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? 0

        let categoryField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "category")!
        let category: String = FieldType(field: categoryField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? ""

        let numeroField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "numero")!
        let numero: Int = FieldType(field: numeroField, lang: lang).parseValue(tokenValueHex: tokenHex) ?? 0

        //TODO derive/extract from XML
        let timeZoneIdentifier = Constants.eventTimeZone

        return Ticket(
                id: MarketQueueHandler.bytesToHexa(tokenId.serialize().array),
                index: index,
                city: locality,
                name: getName(lang: lang),
                venue: venue,
                match: match,
                date: time,
                seatId: numero,
                category: category,
                countryA: countryA,
                countryB: countryB,
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

    func getName(lang: String) -> String {
        if let name = xml["asset"]["contract"][0]["name"].getElementWithLangAttribute(equals: lang)?.text {
            return name
        }
        return "N/A"
    }
    
    func getLang() -> String {
        let lang = Locale.preferredLanguages[0]
        if lang.hasPrefix("en") {
            return "en"
        } else if lang.hasPrefix("zh") {
            return "zh"
        } else if lang.hasPrefix("es") {
            return "es"
        } else if lang.hasPrefix("ru") {
            return "ru"
        }
        return "en"
    }
}

