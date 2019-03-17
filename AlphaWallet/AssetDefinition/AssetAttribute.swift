// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt
import PromiseKit
//TODO make only XMLHandler import Kanna and hence be the only file to handle XML parsing
import Kanna

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

    var solidityReturnType: CallForAssetAttribute.SolidityType {
        switch self {
        case .directoryString, .generalisedTime, .iA5String:
            return .string
        case .integer:
            return .int
        case .bool:
            return .bool
        }
    }

    func extract(from string: String, isMapping: Bool) -> Any? {
        switch self {
        case .generalisedTime:
            //TODO fix 2 possible formats of string value at this point. Where it is GeneralisedTime or encoded instead of using an ugly length check
            //TODO add test case to make sure both formats work
            //e.g. 20180911190201+0800
            let lengthOfGeneralisedTime = 19
            if string.count == lengthOfGeneralisedTime {
                return GeneralisedTime(string: string)
            } else {
                if let value = BigUInt(string), let string = String(data: Data(bytes: String(value, radix: 16).hexa2Bytes), encoding: .utf8) {
                    return GeneralisedTime(string: string)
                } else {
                    return GeneralisedTime()
                }
            }
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
            return string == "TRUE"
        }
    }
}

enum AssetAttribute {
    case mapping(attribute: XMLElement, rootNamespacePrefix: String, namespaces: [String: String], name: String, syntax: AssetAttributeSyntax, lang: String, bitmask: BigUInt, bitShift: Int)
    case direct(attribute: XMLElement, rootNamespacePrefix: String, namespaces: [String: String], name: String, syntax: AssetAttributeSyntax, bitmask: BigUInt, bitShift: Int)
    case function(attribute: XMLElement, rootNamespacePrefix: String, namespaces: [String: String], name: String, syntax: AssetAttributeSyntax, attributeName: String, functionName: String, inputs: [CallForAssetAttribute.Argument], output: CallForAssetAttribute.ReturnType)

    var name: String {
        switch self {
        case .mapping(_, _, _, let name, _, _, _, _):
            return name
        case .direct(_, _, _, let name, _, _, _):
            return name
        case .function(_, _, _, let name, _, _, _, _, _):
            return name
        }
    }

    init(attribute: XMLElement, rootNamespacePrefix: String, namespaces: [String: String], lang: String) {
        self = {
            //TODO show error if syntax attribute is missing
            if let origin = XMLHandler.getOriginElement(fromAttributeTypeElement: attribute, namespacePrefix: rootNamespacePrefix, namespaces: namespaces), let rawSyntax = attribute["syntax"], let syntax = AssetAttributeSyntax(rawValue: rawSyntax), let type = origin["as"], let bitmask = XMLHandler.getBitMaskFrom(fromAttributeTypeElement: attribute, namespacePrefix: rootNamespacePrefix, namespaces: namespaces) {
                let nameElement = XMLHandler.getNameElement(fromAttributeTypeElement: attribute, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang)
                let name = nameElement?.text ?? ""

                let bitShift = AssetAttribute.bitShiftCount(forBitMask: bitmask)
                switch type {
                case "mapping":
                    return .mapping(attribute: attribute, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces, name: name, syntax: syntax, lang: lang, bitmask: bitmask, bitShift: bitShift)
                default:
                    return .direct(attribute: attribute, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces, name: name, syntax: syntax, bitmask: bitmask, bitShift: bitShift)
                }
            }
            //TODO maybe return an optional to indicate error instead?
            return .direct(attribute: attribute, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces, name: "", syntax: .iA5String, bitmask: BigUInt(0), bitShift: 0)
        }()
    }

    init(attribute: XMLElement, functionElement: XMLElement, rootNamespacePrefix: String, namespaces: [String: String], lang: String) {
        self = {
            let nameElement = XMLHandler.getNameElement(fromAttributeTypeElement: attribute, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang)
            let name = nameElement?.text ?? ""

            if let attributeName = attribute["id"],
               let rawSyntax = attribute["syntax"],
               let syntax = AssetAttributeSyntax(rawValue: rawSyntax),
               let functionName = functionElement["name"],
               !functionName.isEmpty {
                let inputs: [CallForAssetAttribute.Argument]
                let returnType = syntax.solidityReturnType
                let output = CallForAssetAttribute.ReturnType(type: returnType)
                if let inputsElement = XMLHandler.getInputsElement(fromFunctionElement: functionElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces) {
                    inputs = AssetAttribute.extractInputs(fromInputsElement: inputsElement)
                } else {
                    inputs = []
                }

                return .function(attribute: attribute, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces, name: name, syntax: syntax, attributeName: attributeName, functionName: functionName, inputs: inputs, output: output)
            } else {
                //TODO maybe return an optional to indicate error instead?
                return .direct(attribute: attribute, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces, name: name, syntax: .iA5String, bitmask: BigUInt(0), bitShift: 0)
            }
        }()
    }

    public static func extractInputs(fromInputsElement inputsElement: XMLElement) -> [CallForAssetAttribute.Argument] {
        return XMLHandler.getInputs(fromInputsElement: inputsElement).compactMap {
            if let inputTypeString = $0.tagName, !inputTypeString.isEmpty, let inputName = $0["ref"], !inputName.isEmpty, let inputType = CallForAssetAttribute.SolidityType(rawValue: inputTypeString) {
                return .init(name: inputName, type: inputType)
            } else {
                return nil
            }
        }
    }

    func extract(from tokenValue: BigUInt, ofContract contract: String, server: RPCServer, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?) -> AssetAttributeValue {
        switch self {
        case .mapping(_, _, _, _, let syntax, _, _, _), .direct(_, _, _, _, let syntax, _, _):
            switch syntax {
            case .directoryString, .iA5String:
                let value: String = extract(from: tokenValue, ofContract: contract, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? "N/A"
                return value
            case .generalisedTime:
                let value: GeneralisedTime = extract(from: tokenValue, ofContract: contract, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? .init()
                return value
            case .integer:
                let value: Int = extract(from: tokenValue, ofContract: contract, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? 0
                return value
            case .bool:
                let value: Bool = extract(from: tokenValue, ofContract: contract, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) ?? false
                return value
            }
        case .function(_, _, _, _, let syntax, _, _, _, _):
            if let subscribableAttributeValue: SubscribableAssetAttributeValue = extract(from: tokenValue, ofContract: contract, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator) {
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

    private func extract<T>(from tokenValue: BigUInt, ofContract contract: String, server: RPCServer, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?) -> T? where T: AssetAttributeValue {
        switch self {
        case .mapping(let attribute, let rootNamespacePrefix, let namespaces, _, let syntax, let lang, _, _):
            guard let key = parseValue(tokenValue: tokenValue) else { return nil }
            guard let value = XMLHandler.getMappingOptionValue(fromAttributeElement: attribute, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, withKey: String(key), forLang: lang) else { return nil }
            return syntax.extract(from: value, isMapping: true) as? T
        case .direct(_, _, _, _, let syntax, _, _):
            guard let value = parseValue(tokenValue: tokenValue) else { return nil }
            return syntax.extract(from: String(value), isMapping: false) as? T
        case .function(_, _, _, _, _, let attributeName, let functionName, let inputs, let output):
            let arguments: [AnyObject]
            //TODO we only support tokenID for now
            if inputs.count == 1 && (inputs[0].name == "tokenID" || inputs[0].name == "TokenID") {
                //TODO what format do we need to pass the tokenValue in?
                arguments = [String(tokenValue) as NSString]
            } else {
                arguments = []
            }

            let functionCall = AssetAttributeFunctionCall(
                    server: server,
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
        case .direct(_, _, _, _, _, let bitmask, let bitShift), .mapping(_, _, _, _, _, _, let bitmask, let bitShift):
            return (bitmask & tokenValue) >> bitShift
        case .function:
            return nil
        }
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
