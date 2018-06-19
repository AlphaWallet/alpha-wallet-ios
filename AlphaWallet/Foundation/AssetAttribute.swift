// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import SwiftyXMLParser

protocol AssetAttributeValue {}
extension String: AssetAttributeValue {}
extension Int: AssetAttributeValue {}
extension GeneralisedTime: AssetAttributeValue {}

enum AssetAttributeSyntax: String {
    case directoryString = "1.3.6.1.4.1.1466.115.121.1.15"
    case generalisedTime = "1.3.6.1.4.1.1466.115.121.1.24"
    case iA5String = "1.3.6.1.4.1.1466.115.121.1.26"
    case integer = "1.3.6.1.4.1.1466.115.121.1.27"

    func extract(from string: String, isMapping: Bool) -> Any? {
        switch self {
        case .generalisedTime:
            return GeneralisedTime(string: string)
        case .directoryString, .iA5String:
            if isMapping {
                return string
            } else {
                return String(data: Data(bytes: string.hexa2Bytes), encoding: .utf8)
            }
        case .integer:
            if let intValue = Int(string, radix: 16) {
                return intValue
            }
            return nil
        }
    }
}

enum AssetAttribute {
    case mapping(attribute: XML.Accessor, syntax: AssetAttributeSyntax, lang: String)
    case direct(attribute: XML.Accessor, syntax: AssetAttributeSyntax)

    init(attribute: XML.Element, lang: String) {
        self = {
            let attributeAccessor = XML.Accessor(attribute)
            let attribute = XML.Accessor(attribute)
            //TODO show error if syntax attribute is missing
            if case .singleElement(let origin) = attributeAccessor["origin"], let rawSyntax = attributeAccessor.attributes["syntax"], let syntax = AssetAttributeSyntax(rawValue: rawSyntax),  let type = XML.Accessor(origin).attributes["as"] {
                switch type {
                case "mapping":
                    return .mapping(attribute: attributeAccessor, syntax: syntax, lang: lang)
                default:
                    return .direct(attribute: attributeAccessor, syntax: syntax)
                }
            }
            //TODO maybe return an optional to indicate error instead?
            return .direct(attribute: attributeAccessor, syntax: .iA5String)
        }()
    }

    func extract<T>(from tokenValueHex: String) -> T? where T: AssetAttributeValue {
        switch self {
        case .mapping(let _, let syntax, _):
            guard let value = parseValueFromMapping(tokenValueHex: tokenValueHex) else { return nil }
            return syntax.extract(from: value, isMapping: true) as? T
        case .direct(let _, let syntax):
            let value = parseValue(tokenValueHex: tokenValueHex)
            return syntax.extract(from: value, isMapping: false) as? T
        }
    }

    private func parseValue(tokenValueHex: String) -> String {
        let (start, end) = getIndices(forTokenValueHexLength: tokenValueHex.count)
        return tokenValueHex.substring(with: Range(uncheckedBounds: (start, end)))
    }

    private func parseValueAsIntInHex(tokenValueHex: String) -> String {
        let value = parseValue(tokenValueHex: tokenValueHex)
        if let intValue = Int(value, radix: 16) {
            return String(intValue)
        }
        return "0"
    }

    private func parseValueFromMapping(tokenValueHex: String) -> String? {
        switch self {
        case .mapping(let attribute, _, let lang):
            let id = parseValueAsIntInHex(tokenValueHex: tokenValueHex)
            guard id != "0" else { return nil }
            if let value = attribute["origin"]["option"].getElementWithKeyAttribute(equals: id)?["value"].getElementWithLangAttribute(equals: lang)?.text {
                return value
            }
            return nil
        case .direct:
            return nil
        }
    }

    private func handleBitmaskIndices(bitmask: String, forTokenValueHexLength length: Int) -> (Int, Int) {
        var startingNumber = 0
        var endingNumber = 0
        let diff = bitmask.count - length
        let trimmedBitmask = bitmask.substring(from: diff)
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

    private func getBitMaskFrom(attribute: XML.Accessor) -> String? {
        return attribute["origin"].attributes["bitmask"]
    }

    private func getIndices(forTokenValueHexLength length: Int) -> (Int, Int) {
        switch self {
        case .direct(let attribute, _), .mapping(let attribute, _, _):
            if let bitmask = getBitMaskFrom(attribute: attribute) {
                return handleBitmaskIndices(bitmask: bitmask, forTokenValueHexLength: length)
            }
        }
        return (0, 0)
    }
}
