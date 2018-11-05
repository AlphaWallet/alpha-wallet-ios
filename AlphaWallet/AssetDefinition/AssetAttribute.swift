// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt
import PromiseKit
import SwiftyXMLParser

protocol AssetAttributeValue {}
extension String: AssetAttributeValue {}
extension Int: AssetAttributeValue {}
extension GeneralisedTime: AssetAttributeValue {}
extension Array: AssetAttributeValue {}
extension Bool: AssetAttributeValue {}
struct SubscribableAssetAttributeValue: AssetAttributeValue {
    let subscribable: Subscribable<AssetAttributeValue>
}

enum AssetAttributeSyntax: String {
    case directoryString = "1.3.6.1.4.1.1466.115.121.1.15"
    case generalisedTime = "1.3.6.1.4.1.1466.115.121.1.24"
    case iA5String = "1.3.6.1.4.1.1466.115.121.1.26"
    case integer = "1.3.6.1.4.1.1466.115.121.1.27"
    case bool = "1.3.6.1.4.1.1466.115.121.1.7"

    var solidityReturnType: CallForAssetAttribute.SolidityType  {
        switch self {
        case .directoryString, .generalisedTime, .iA5String:
            return .string
        case .integer:
            return .int
        case .bool:
            return .bool
        default:
            return .string
        }
    }

    func extract(from string: String, isMapping: Bool) -> Any? {
        switch self {
        case .generalisedTime:
            return GeneralisedTime(string: string)
        case .directoryString, .iA5String:
            if isMapping {
                return string
            } else {
                guard let value = BigUInt(string) else { return "" }
                return String(data: Data(bytes: String(value, radix: 16).hexa2Bytes), encoding: .utf8)
            }
        case .integer:
            return Int(string)
        case .bool:
            return string == "1"
        }
    }
}

enum AssetAttribute {
    case mapping(attribute: XML.Accessor, rootNamespacePrefix: String, syntax: AssetAttributeSyntax, lang: String, bitmask: BigUInt, bitShift: Int)
    case direct(attribute: XML.Accessor, rootNamespacePrefix: String, syntax: AssetAttributeSyntax, bitmask: BigUInt, bitShift: Int)
    case function(attribute: XML.Accessor, rootNamespacePrefix: String, syntax: AssetAttributeSyntax, attributeName: String, functionName: String, inputs: [CallForAssetAttribute.Argument], output: CallForAssetAttribute.ReturnType)

    init(attribute: XML.Element, rootNamespacePrefix: String, lang: String) {
        self = {
            let attributeAccessor = XML.Accessor(attribute)
            //TODO show error if syntax attribute is missing
            if case .singleElement(let origin) = attributeAccessor["\(rootNamespacePrefix)origin"], let rawSyntax = attributeAccessor.attributes["syntax"], let syntax = AssetAttributeSyntax(rawValue: rawSyntax), let type = XML.Accessor(origin).attributes["as"], let bitmaskString = AssetAttribute.getBitMaskFrom(attribute: attributeAccessor, rootNamespacePrefix: rootNamespacePrefix), let bitmask = BigUInt(bitmaskString, radix: 16) {
                let bitShift = AssetAttribute.bitShiftCount(forBitMask: bitmask)
                switch type {
                case "mapping":
                    return .mapping(attribute: attributeAccessor, rootNamespacePrefix: rootNamespacePrefix, syntax: syntax, lang: lang, bitmask: bitmask, bitShift: bitShift)
                default:
                    return .direct(attribute: attributeAccessor, rootNamespacePrefix: rootNamespacePrefix, syntax: syntax, bitmask: bitmask, bitShift: bitShift)
                }
            }
            //TODO maybe return an optional to indicate error instead?
            return .direct(attribute: attributeAccessor, rootNamespacePrefix: rootNamespacePrefix, syntax: .iA5String, bitmask: BigUInt(0), bitShift: 0)
        }()
    }

    //TODO combine with the `init()` above
    init(attribute: XML.Element, rootNamespacePrefix: String) {
        self = {
            let attributeAccessor = XML.Accessor(attribute)
            let functionElement = attributeAccessor["\(rootNamespacePrefix)origin"]["\(rootNamespacePrefix)function"]

            if let attributeName = attributeAccessor.attributes["id"], case .singleElement(let origin) = attributeAccessor["\(rootNamespacePrefix)origin"], let rawSyntax = attributeAccessor.attributes["syntax"], let syntax = AssetAttributeSyntax(rawValue: rawSyntax), let functionName = functionElement.text?.dropParenthesis, !functionName.isEmpty {
                let inputs: [CallForAssetAttribute.Argument]
                let returnType = syntax.solidityReturnType
                let output = CallForAssetAttribute.ReturnType(type: returnType)


                switch functionElement["\(rootNamespacePrefix)value"] {
                case .singleElement(let inputElement):
                    if let inputTypeString = inputElement.text, !inputTypeString.isEmpty, let inputName = inputElement.attributes["ref"], !inputName.isEmpty, let inputType = CallForAssetAttribute.SolidityType(rawValue: inputTypeString) {
                        inputs = [.init(name: inputName, type: inputType)]
                    } else {
                        inputs = []
                    }
                case .sequence(let inputElements):
                    inputs = inputElements.compactMap {
                        if let inputTypeString = $0.text, !inputTypeString.isEmpty, let inputName = $0.attributes["ref"], !inputName.isEmpty, let inputType = CallForAssetAttribute.SolidityType(rawValue: inputTypeString) {
                            return .init(name: inputName, type: inputType)
                        } else {
                            return nil
                        }
                    }
                case .failure:
                    inputs = []
                }

                return .function(attribute: attributeAccessor, rootNamespacePrefix: rootNamespacePrefix, syntax: syntax, attributeName: attributeName, functionName: functionName, inputs: inputs, output: output)
            } else {
                //TODO maybe return an optional to indicate error instead?
                return .direct(attribute: attributeAccessor, rootNamespacePrefix: rootNamespacePrefix, syntax: .iA5String, bitmask: BigUInt(0), bitShift: 0)
            }
        }()
    }

   func extract(from tokenValue: BigUInt, ofContract contract: String, config: Config, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?) -> AssetAttributeValue {
        switch self {
        case .mapping(_, _, let syntax, _, _, _), .direct(_, _, let syntax, _, _):
            switch syntax {
            case .directoryString, .iA5String:
                let value: String = extract(from: tokenValue, ofContract: contract, config: config, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? "N/A"
                return value
            case .generalisedTime:
                let value: GeneralisedTime = extract(from: tokenValue, ofContract: contract, config: config, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? .init()
                return value
            case .integer:
                let value: Int = extract(from: tokenValue, ofContract: contract, config: config, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? 0
                return value
            case .bool:
                let value: Bool = extract(from: tokenValue, ofContract: contract, config: config, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? false
                return value
            }
        case .function(_, _, let syntax, _, _, _, _):
            if let subscribableAttributeValue: SubscribableAssetAttributeValue = extract(from: tokenValue, ofContract: contract, config: config, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) {
                return subscribableAttributeValue
            } else {
                switch syntax {
                case .directoryString, .iA5String:
                    return "N/A"
                case .generalisedTime:
                    return GeneralisedTime()
                case .integer:
                    return 0
                case .bool:
                    return false
                }
            }
        }
    }

    private func extract<T>(from tokenValue: BigUInt, ofContract contract: String, config: Config, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?) -> T? where T: AssetAttributeValue {
        switch self {
        case .mapping(let attribute, let rootNamespacePrefix, let syntax, let lang, _, _):
            guard let key = parseValue(tokenValue: tokenValue) else { return nil }
            guard let value = attribute["\(rootNamespacePrefix)origin"]["\(rootNamespacePrefix)option"].getElementWithKeyAttribute(equals: String(key))?["\(rootNamespacePrefix)value"].getElementWithLangAttribute(equals: lang)?.text else { return nil }
            return syntax.extract(from: value, isMapping: true) as? T
        case .direct(_, _, let syntax, _, _):
            guard let value = parseValue(tokenValue: tokenValue) else { return nil }
            return syntax.extract(from: String(value), isMapping: false) as? T
        case .function(_, _, _, let attributeName, let functionName, let inputs, let output):
            let arguments: [AnyObject]
            //TODO we only support tokenID for now
            if inputs.count == 1 && (inputs[0].name == "tokenID" || inputs[0].name == "TokenID")  {
                //TODO what format do we need to pass the tokenValue in?
                arguments = [String(tokenValue) as NSString]
            } else {
                arguments = []
            }

            let functionCall = AssetAttributeFunctionCall(
                    server: config.server,
                    contract: contract,
                    functionName: functionName,
                    inputs: inputs,
                    output: output,
                    arguments: arguments
            )
            let subscribable = callSmartContractFunction(
                    forAttributeName: attributeName,
                    tokenId: tokenValue,
                    functionCall: functionCall,
                    callForAssetAttributeCoordinator: callForAssetAttributeCoordinator
            )
            return SubscribableAssetAttributeValue(subscribable: subscribable) as? T
        }
    }

    private func parseValue(tokenValue: BigUInt) -> BigUInt? {
        switch self {
        case .direct(_, _, _, let bitmask, let bitShift), .mapping(_, _, _, _, let bitmask, let bitShift):
            return (bitmask & tokenValue) >> bitShift
        case .function:
            return nil
        }
    }

    private static func getBitMaskFrom(attribute: XML.Accessor, rootNamespacePrefix: String) -> String? {
        return attribute["\(rootNamespacePrefix)origin"].attributes["bitmask"]
    }

    ///Used to truncate bits to the right of the bitmask
    private static func bitShiftCount(forBitMask bitmask: BigUInt) -> Int {
        var count = 0
        repeat {
            count += 1
        } while bitmask % (1 << count) == 0
        return count - 1
    }

    private func callSmartContractFunction(
            forAttributeName attributeName: String,
            tokenId: BigUInt,
            functionCall: AssetAttributeFunctionCall,
            callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?
    ) -> Subscribable<AssetAttributeValue> {
        guard let callForAssetAttributeCoordinator = callForAssetAttributeCoordinator else {
            return Subscribable<AssetAttributeValue>(nil)
        }
        return callForAssetAttributeCoordinator.getValue(forAttributeName: attributeName, tokenId: tokenId, functionCall: functionCall)
    }
}
