// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import SwiftyXMLParser

//kkk or FieldValue?
protocol FieldValueType {}
extension String: FieldValueType {}
extension Int: FieldValueType {}
extension Date: FieldValueType {}

enum FieldType {
    case Enumeration(field: XML.Element, lang: String)
    case IA5String(field: XML.Element)
    case BinaryTime(field: XML.Element)
    case Integer(field: XML.Element)

    init(field: XML.Element, lang: String) {
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
                    return .Enumeration(field: field, lang: lang)
                default:
                    return .IA5String(field: field)
                }
            } else {
                return .IA5String(field: field)
            }
        }()
    }

    func parseValue<T>(tokenValueHex: String) -> T? where T: FieldValueType {
        switch self {
        case .Enumeration(let field):
            return parseValueFromEnumeration(tokenValueHex: tokenValueHex) as? T
        case .IA5String(let field):
            return parseValueAsAscii(tokenValueHex: tokenValueHex) as? T
        case .BinaryTime(let field):
            return parseValueAsDate(tokenValueHex: tokenValueHex) as? T
        case .Integer(let field):
            return parseValueAsInt(tokenValueHex: tokenValueHex) as? T
        }
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

    func parseValueAsDate(tokenValueHex: String) -> Date {
        //TODO: parseValueAsInt() returns 1 if parsing was not successful. Maybe we should return a special date here instead of using `1`?
        let time = parseValueAsInt(tokenValueHex: tokenValueHex)
        return Date(timeIntervalSince1970: TimeInterval(time))
    }

    func parseValueFromEnumeration(tokenValueHex: String) -> String {
        switch self {
        case .Enumeration(let field, let lang):
            //TODO better if we can parse as "raw string" instead of converting back and forth and thus assuming the value is numeric. But note that `bytesToHexa()` returns '02' instead of '2'
            let id = String(parseValueAsInt(tokenValueHex: tokenValueHex))
            //kkk "N/A"
            guard id != "0" else { return "N/A" }
            //kkk use of XML.Accessor good? Maybe getElement(attributeName:attributeValue:) should return an XML.Accessor instead
            if let value = XML.Accessor(XML.Accessor(field)["mapping"]["entity"].getElementWithKeyAttribute(equals: id)!)["name"].getElementWithLangAttribute(equals: lang)?.text {
                return value
            }
            return "N/A"
        case .IA5String(let field):
            //kkk how?
            return ""
        case .BinaryTime(let field):
            //kkk how?
            return ""
        case .Integer(let field):
            //kkk how?
            return ""
        }
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
        case .Enumeration(let field, let _):
            if let bitmask = field.attributes["bitmask"] {
                return handleBitmaskIndices(bitmask: bitmask)
            }
        }
        return (0, 0)
    }
}
