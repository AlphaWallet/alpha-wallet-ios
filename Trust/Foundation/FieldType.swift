// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import SwiftyXMLParser

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
