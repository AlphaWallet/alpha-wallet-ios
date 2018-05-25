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
}

enum FieldType {
    init(field: XML.Element) {
        self = {
            if let type = field.attributes["type"] {
                switch type {
                case "IA5String":
                    return .IA5String(field: field)
                case "BinaryTime":
                    return .BinaryTime(field: field)
                case "Integer":
                    return .Integer(field: field)
                case "Enumeration":
                    return .Enumeration(field: field)
                default:
                    return .IA5String(field: field)
                }
            } else {
                return .IA5String(field: field)
            }
        }()
    }
    
    func parseValueAsAscii(tokenValueHex: String) -> String {
        let (start, end) = getIndices()
        let value = tokenValueHex.substring(with: Range(uncheckedBounds: (start, end))).hexa2Bytes
        return String(data: Data(bytes: value), encoding: .utf8) ?? "TBD"
    }
    
    func parseValueAsInt(tokenValueHex: String) -> Int {
        let (start, end) = getIndices()
        let value = tokenValueHex.substring(with: Range(uncheckedBounds: (start, end))).hexa2Bytes
        if let intValue = Int(MarketQueueHandler.bytesToHexa(value), radix: 16) {
            return intValue
        }
        return 1
    }
    
    func parseValueFromEnumeration(tokenValueHex: String, id: String) -> String {
        let (start, end) = getIndices()
        let value = tokenValueHex.substring(with: Range(uncheckedBounds: (start, end))).hexa2Bytes
        if let entityKey = Int(MarketQueueHandler.bytesToHexa(value), radix: 16) {
            //get entity key and id for corresponding value of enumeration
            
        }
        return ""
    }
    
    func handleBitmaskIndices(bitmask: String) -> (Int, Int) {
        var startingNumber = 0
        var endingNumber = 0
        //todo temporary
        let trimmedBitmask = bitmask.substring(from: 32)
        for i in 0...trimmedBitmask.count {
            if trimmedBitmask.substring(with: Range(uncheckedBounds: (i, i + 1))) == "F" {
                startingNumber = i
                break
            }
        }
        let strippedBitmask = trimmedBitmask.replacingOccurrences(of: "0", with: "")
        endingNumber = strippedBitmask.count + startingNumber
        return (startingNumber, endingNumber)
    }
    
    func getIndices() -> (Int, Int) {
        switch self {
        case .IA5String(let field):
            if let bitmask = field.attributes["bitmask"] {
                return handleBitmaskIndices(bitmask: bitmask)
            }
        case .BinaryTime(let field):
            if let bitmask = field.attributes["bitmask"] {
                return handleBitmaskIndices(bitmask: bitmask)
            }
        case .Integer(let field):
            if let bitmask = field.attributes["bitmask"] {
                return handleBitmaskIndices(bitmask: bitmask)
            }
        case .Enumeration(let field):
            if let bitmask = field.attributes["bitmask"] {
                return handleBitmaskIndices(bitmask: bitmask)
            }
        }
        return (0, 0)
    }
    case Enumeration(field: XML.Element)
    case IA5String(field: XML.Element)
    case BinaryTime(field: XML.Element)
    case Integer(field: XML.Element)
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
        let location = getLocality(attribute: tokenHex.substring(to: 2), lang: lang)
        let venue = getVenue(attribute: tokenHex.substring(with: Range(uncheckedBounds: (2, 4))), lang: lang)
        let timeField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "time")!
        let time = FieldType(field: timeField).parseValueAsInt(tokenValueHex: tokenHex)
        //translatable to ascii
        let countryAField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "countryA")!
        let countryAString = FieldType(field: countryAField).parseValueAsAscii(tokenValueHex: tokenHex)
        let countryBField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "countryB")!
        let countryBString = FieldType(field: countryBField).parseValueAsAscii(tokenValueHex: tokenHex)
        let matchField = xml["asset"]["fields"]["field"].getElement(attributeName: "id", attributeValue: "match")!
        let match = FieldType(field: matchField).parseValueAsInt(tokenValueHex: tokenHex)
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

    func getName(lang: String) -> String {
        if let name = xml["asset"]["contract"][0]["name"].getElement(attributeName: "lang", attributeValue: lang)?.text {
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

    func getLocality(attribute: String, lang: String) -> String {
        //entity keys start at 1 but xml finder starts at 0, hence -1
        if let locality = Int(attribute, radix: 16) {
            guard locality != 0 else { return "N/A" }
            if let parsedLocality = xml["asset"]["fields"]["field"][0][0]["mapping"]["entity"][locality - 1]["name"].getElement(attributeName: "lang", attributeValue: lang)?.text {
                return parsedLocality
            }
        }
        return "N/A"
    }
    
    func getCategory(_ cat: Int, lang: String) -> String {
        guard cat != 0 else { return "N/A" }
        if let category = xml["asset"]["fields"]["field"][6][0]["mapping"]["entity"][cat - 1]["name"].getElement(attributeName: "lang", attributeValue: lang)?.text {
            return category
        }
        return "N/A"
    }

    func getVenue(attribute: String, lang: String) -> String {
        if let venueNumber = Int(attribute, radix: 16) {
            guard venueNumber != 0 else { return "N/A" }
            if let parsedVenue = xml["asset"]["fields"]["field"][1][0]["mapping"]["entity"][venueNumber - 1]["name"].getElement(attributeName: "lang", attributeValue: lang)?.text {
                return parsedVenue
            }
        }
        return "N/A"
    }

}
