//
//  ABIRecordParser.swift
//  web3swift
//
//  Created by Alexander Vlasov on 06.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation

public enum ParsingError: Error {
    case invalidJsonFile
    case elementTypeInvalid
    case elementNameInvalid
    case functionInputInvalid
    case functionOutputInvalid
    case eventInputInvalid
    case parameterTypeInvalid
    case parameterTypeNotFound
    case abiInvalid
}

enum TypeMatchingExpressions {
    static var typeRegex = "^([^0-9\\s]*?)([1-9][0-9]*)?$"
    static var arrayRegex = "^([^0-9\\s]*?)([1-9][0-9]*)?(\\[([1-9][0-9]*)?\\])*?$"
}

fileprivate enum ElementType: String {
    case function
    case constructor
    case fallback
    case event
}

extension ABIRecord {
    public func parse() throws -> ABIElement {
        let typeString = self.type != nil ? self.type! : "function"
        guard let type = ElementType(rawValue: typeString) else {
            throw ParsingError.elementTypeInvalid
        }
        return try parseToElement(from: self, type: type)
    }
}

fileprivate func parseToElement(from abiRecord: ABIRecord, type: ElementType) throws -> ABIElement {
    switch type {
    case .function:
        let function = try parseFunction(abiRecord: abiRecord)
        return ABIElement.function(function)
    case .constructor:
        let constructor = try parseConstructor(abiRecord: abiRecord)
        return ABIElement.constructor(constructor)
    case .fallback:
        let fallback = try parseFallback(abiRecord: abiRecord)
        return ABIElement.fallback(fallback)
    case .event:
        let event = try parseEvent(abiRecord: abiRecord)
        return ABIElement.event(event)
    }
}

fileprivate func parseFunction(abiRecord: ABIRecord) throws -> ABIElement.Function {
    let abiInputs = try abiRecord.inputs?.map { input throws -> ABIElement.Function.Input in
        let parameterType = try parseType(from: input.type)
        return ABIElement.Function.Input(name: input.name ?? "", type: parameterType)
    } ?? []

    let abiOutputs = try abiRecord.outputs?.map { output throws -> ABIElement.Function.Output in
        let parameterType = try parseType(from: output.type)
        return ABIElement.Function.Output(name: output.name ?? "", type: parameterType)
    } ?? []

    let name = abiRecord.name ?? ""
    let payable = abiRecord.stateMutability != nil ?
    (abiRecord.stateMutability == "payable" || abiRecord.payable!) : false
    let constant = (abiRecord.constant! || abiRecord.stateMutability == "view" || abiRecord.stateMutability == "pure")

    return ABIElement.Function(name: name, inputs: abiInputs, outputs: abiOutputs, constant: constant, payable: payable)
}

fileprivate func parseFallback(abiRecord: ABIRecord) throws -> ABIElement.Fallback {
    let payable = abiRecord.stateMutability == "payable" || abiRecord.payable!
    var constant = false
    if abiRecord.constant != nil {
        constant = abiRecord.constant!
    }
    if abiRecord.stateMutability == "view" || abiRecord.stateMutability == "pure" {
        constant = true
    }

    return ABIElement.Fallback(constant: constant, payable: payable)
}

fileprivate func parseConstructor(abiRecord: ABIRecord) throws -> ABIElement.Constructor {
    let abiInputs = try abiRecord.inputs?.map { input throws -> ABIElement.Function.Input in
        let parameterType = try parseType(from: input.type)
        return ABIElement.Function.Input(name: input.name ?? "", type: parameterType)
    } ?? []

    var payable = false
    if abiRecord.payable != nil {
        payable = abiRecord.payable!
    }
    if abiRecord.stateMutability == "payable" {
        payable = true
    }

    return ABIElement.Constructor(inputs: abiInputs, constant: false, payable: payable)
}

fileprivate func parseEvent(abiRecord: ABIRecord) throws -> ABIElement.Event {
    let abiInputs = try abiRecord.inputs?.map { input throws -> ABIElement.Event.Input in
        let parameterType = try parseType(from: input.type)
        return ABIElement.Event.Input(name: input.name ?? "", type: parameterType, indexed: input.indexed ?? false)
    } ?? []

    return ABIElement.Event(name: abiRecord.name ?? "", inputs: abiInputs, anonymous: abiRecord.anonymous ?? false)
}

extension ABIInput {
    func parse() throws -> ABIElement.Function.Input {
        let paramType = try parseType(from: self.type)
        return ABIElement.Function.Input(name: name ?? "", type: paramType)
    }
    
    func parseForEvent() throws -> ABIElement.Event.Input {
        let paramType = try parseType(from: self.type)
        return ABIElement.Event.Input(name: self.name ?? "", type: paramType, indexed: self.indexed ?? false)
    }
}

public struct ABITypeParser {
    public static func parseTypeString(_ string: String) throws -> ABIElement.ParameterType {
        return try parseType(from: string)
    }
}

fileprivate func parseType(from string: String) throws -> ABIElement.ParameterType {
    let possibleType = try typeMatch(from: string) ?? arrayMatch(from: string)
    guard let foundType = possibleType else {
        throw ParsingError.parameterTypeInvalid
    }
    guard foundType.isValid else {
        throw ParsingError.parameterTypeInvalid
    }
    return foundType
}

    /// Types that are "atomic" can be matched exactly to these strings
fileprivate enum ExactMatchParameterType: String {
    // Static Types
    case address
    case uint
    case int
    case bool
    case function
    
    // Dynamic Types
    case bytes
    case string
}

fileprivate func exactMatchType(from string: String, length: UInt64? = nil, staticArrayLength: UInt64? = nil) -> ABIElement.ParameterType? {
        // Check all the exact matches by trying to create a ParameterTypeKey from it.
    switch ExactMatchParameterType(rawValue: string) {
        
            // Static Types
    case .address?:
        return .staticABIType(.address)
    case .uint?:
        return .staticABIType(.uint(bits: length != nil ? UInt64(length!) : 256))
    case .int?:
        return .staticABIType(.int(bits: length != nil ? UInt64(length!) : 256))
    case .bool?:
        return .staticABIType(.bool)
            //    case .function?:
            //        return .staticABIType(.function)
        
            // Dynamic Types
    case .bytes?:
        if length != nil { return .staticABIType(.bytes(length: UInt64(length!))) }
        return .dynamicABIType(.bytes)
    case .string?:
        return .dynamicABIType(.string)
    default:
        guard let arrayLen = staticArrayLength else { return nil }
        guard let baseType = exactMatchType(from: string, length: length) else { return nil }
        switch baseType {
        case .staticABIType(let unwrappedType):
            if staticArrayLength == 0 {
                return .dynamicABIType(.dynamicArray(unwrappedType))
            }
            return .staticABIType(.array(unwrappedType, length: UInt64(arrayLen)))
        case .dynamicABIType(let unwrappedType):
            if staticArrayLength == 0 {
                return .dynamicABIType(.arrayOfDynamicTypes(unwrappedType, length: UInt64(arrayLen)))
            }
            return nil
        }
    }
}

fileprivate let typeRegex = try? NSRegularExpression(pattern: TypeMatchingExpressions.typeRegex, options: .dotMatchesLineSeparators)
fileprivate func typeMatch(from string: String) throws -> ABIElement.ParameterType? {
    guard let matcher = typeRegex else { return nil }
    let match = matcher.matches(in: string, options: NSRegularExpression.MatchingOptions.anchored, range: string.fullNSRange)
    guard match.count == 1 else { return nil }
    guard match[0].numberOfRanges == 3 else { return nil }
    let typeString = String(string[Range(match[0].range(at: 1), in: string)!])
    guard let type = exactMatchType(from: typeString) else { return nil }
    guard let typeRange = Range(match[0].range(at: 2), in: string) else { return type }
    let typeLengthString = String(string[typeRange])
    guard let typeLength = UInt64(typeLengthString) else { throw ParsingError.parameterTypeInvalid }
    guard let canonicalType = exactMatchType(from: typeString, length: typeLength) else { throw ParsingError.parameterTypeInvalid }
    return canonicalType
}

let arrayRegex = try? NSRegularExpression(pattern: TypeMatchingExpressions.arrayRegex, options: .dotMatchesLineSeparators)
// swiftlint:disable function_body_length
fileprivate func arrayMatch(from string: String) throws -> ABIElement.ParameterType? {
    guard let matcher = arrayRegex else { return nil }
    let match = matcher.matches(in: string, options: NSRegularExpression.MatchingOptions.anchored, range: string.fullNSRange)
    guard match.count == 1 else { return nil }
    guard match[0].numberOfRanges >= 4 else { return nil }
    var arrayOfRanges = [NSRange]()
    var totallyIsDynamic = false
    for i in 3 ..< match[0].numberOfRanges {
        let t = Range(match[0].range(at: i), in: string)
        if t == nil && i > 3 {
            continue
        }
        guard let arrayRange = t else {
            throw ParsingError.parameterTypeInvalid
        }
        let arraySizeString = String(string[arrayRange])
        arrayOfRanges.append(match[0].range(at: i))
        if arraySizeString.trimmingCharacters(in: CharacterSet(charactersIn: "[]")) == "" {
            if totallyIsDynamic == false {
                totallyIsDynamic = true // one level of dynamicity
            } else {
                throw ParsingError.parameterTypeInvalid // nested dynamic arrays are not allowed (yet)
            }
        }
    }
    if !totallyIsDynamic { // all arrays are static
        guard let typeRange = Range(match[0].range(at: 1), in: string) else { return nil }
        let typeString = String(string[typeRange])
        guard var type = exactMatchType(from: typeString) else { return nil }
        let typeLengthRange = Range(match[0].range(at: 2), in: string)
        if typeLengthRange != nil {
            let typeLengthString = String(string[typeLengthRange!])
            guard let typeLength = UInt64(typeLengthString) else { throw ParsingError.parameterTypeInvalid }
            guard let canonicalType = exactMatchType(from: typeString, length: typeLength) else { throw ParsingError.parameterTypeInvalid }
            type = canonicalType
        }
        switch type {
        case .staticABIType(let unwrappedType): // all arrays are static and type is static, so we return static variable
            var finalStaticSubtype: ABIElement.ParameterType.StaticType?
            for range in arrayOfRanges {
                guard let r = Range(range, in: string) else { return nil }
                let arraySizeString = String(string[r])
                guard let arraySize = UInt64(arraySizeString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) else { throw ParsingError.parameterTypeInvalid }
                if finalStaticSubtype == nil {
                    let subtype = ABIElement.ParameterType.StaticType.array(unwrappedType, length: arraySize)
                    finalStaticSubtype = subtype
                } else {
                    let subtype = ABIElement.ParameterType.StaticType.array(finalStaticSubtype!, length: arraySize)
                    finalStaticSubtype = subtype
                }
                guard finalStaticSubtype != nil else { throw ParsingError.parameterTypeInvalid }
                return ABIElement.ParameterType.staticABIType(finalStaticSubtype!)
            }
        case .dynamicABIType(let unwrappedType): // all arrays are static but type is dynamic, so we return dynamic
            var finalDynamicSubtype: ABIElement.ParameterType.DynamicType?
            for range in arrayOfRanges {
                guard let r = Range(range, in: string) else { return nil }
                let arraySizeString = String(string[r])
                guard let arraySize = UInt64(arraySizeString.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) else { throw ParsingError.parameterTypeInvalid }
                if finalDynamicSubtype == nil {
                    let subtype = ABIElement.ParameterType.DynamicType.arrayOfDynamicTypes(unwrappedType, length: arraySize)
                    finalDynamicSubtype = subtype
                } else {
                    let subtype = ABIElement.ParameterType.DynamicType.arrayOfDynamicTypes(finalDynamicSubtype!, length: arraySize)
                    finalDynamicSubtype = subtype
                }
                guard finalDynamicSubtype != nil else { throw ParsingError.parameterTypeInvalid }
                return ABIElement.ParameterType.dynamicABIType(finalDynamicSubtype!)
            }
        }
    } else { // one of the arrays is dynamic
        guard let typeRange = Range(match[0].range(at: 1), in: string) else { return nil }
        let typeString = String(string[typeRange])
        guard var type = exactMatchType(from: typeString) else { return nil }
        let typeLengthRange = Range(match[0].range(at: 2), in: string)
        if typeLengthRange != nil {
            let typeLengthString = String(string[typeLengthRange!])
            guard let typeLength = UInt64(typeLengthString) else { throw ParsingError.parameterTypeInvalid }
            guard let canonicalType = exactMatchType(from: typeString, length: typeLength) else { throw ParsingError.parameterTypeInvalid }
            type = canonicalType
        }
        switch type {
        case .staticABIType(let unwrappedType): // array is dynamic and type is static, so we return dynamic
            var finalDynamicSubtype: ABIElement.ParameterType.DynamicType?
            var tempStaticSubtype: ABIElement.ParameterType.StaticType = unwrappedType
            for range in arrayOfRanges {
                guard let r = Range(range, in: string) else { return nil }
                let arraySizeString = String(string[r]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if arraySizeString == "" {
                    if finalDynamicSubtype == nil { // current depth is dynamic, although we didn't yet start wrapping the static type in arrays
                        let subtype = ABIElement.ParameterType.DynamicType.dynamicArray(tempStaticSubtype)
                        finalDynamicSubtype = subtype
                    } else { // current depth is dynamic and previous one is already dynamic, so throw
                        throw ParsingError.parameterTypeInvalid
                    }
                } else {
                    guard let arraySize = UInt64(arraySizeString) else { throw ParsingError.parameterTypeInvalid }
                    if finalDynamicSubtype == nil { // array size is static and we didn't yet start wrapping static type, so wrap in static
                        let subtype = ABIElement.ParameterType.StaticType.array(tempStaticSubtype, length: arraySize)
                        tempStaticSubtype = subtype
                    } else { // current depth is static, but we have at least ones wrapped in dynamic, so it's statically sized array of dynamic variables
                        let subtype = ABIElement.ParameterType.DynamicType.arrayOfDynamicTypes(finalDynamicSubtype!, length: arraySize)
                        finalDynamicSubtype = subtype
                    }
                }
                guard finalDynamicSubtype != nil else { throw ParsingError.parameterTypeInvalid }
                return ABIElement.ParameterType.dynamicABIType(finalDynamicSubtype!)
            }
        case .dynamicABIType: // variable is dynamic and array is dynamic, not yet allowed
            throw ParsingError.parameterTypeInvalid
        }
    }
    throw ParsingError.parameterTypeInvalid
}
// swiftlint:enable function_body_length
