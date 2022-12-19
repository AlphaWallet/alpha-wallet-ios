//
//  ABIParser.swift
//  web3swift
//
//  Created by Alexander Vlasov on 06.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation

extension ABIv2 {

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

    enum TypeParsingExpressions {
        static var typeEatingRegex = "^((u?int|bytes)([1-9][0-9]*)|(address|bool|string|tuple|bytes)|(\\[([1-9][0-9]*)\\]))"
        static var arrayEatingRegex = "^(\\[([1-9][0-9]*)?\\])?.*$"
    }

    fileprivate enum ElementType: String {
        case function
        case constructor
        case fallback
        case event
    }

}

extension ABIv2.Record {
    public func parse() throws -> ABIv2.Element {
        guard let type = ABIv2.ElementType(rawValue: type ?? "function") else {
            throw ABIv2.ParsingError.elementTypeInvalid
        }
        return try parseToElement(from: self, type: type)
    }
}

fileprivate func parseToElement(from abiRecord: ABIv2.Record, type: ABIv2.ElementType) throws -> ABIv2.Element {
    switch type {
    case .function:
        return ABIv2.Element.function(try parseFunction(abiRecord: abiRecord))
    case .constructor:
        return ABIv2.Element.constructor(try parseConstructor(abiRecord: abiRecord))
    case .fallback:
        return ABIv2.Element.fallback(try parseFallback(abiRecord: abiRecord))
    case .event:
        return ABIv2.Element.event(try parseEvent(abiRecord: abiRecord))
    }
}

fileprivate func parseFunction(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Function {
    let inputs = try abiRecord.inputs?.map { try $0.parse() } ?? []
    let outputs = try abiRecord.outputs?.map { try $0.parse() } ?? []

    let payable = abiRecord.stateMutability != nil ? (abiRecord.stateMutability == "payable" || abiRecord.payable ?? false) : false
    let constant = ((abiRecord.constant ?? false) || abiRecord.stateMutability == "view" || abiRecord.stateMutability == "pure")

    return ABIv2.Element.Function(name: abiRecord.name ?? "", inputs: inputs, outputs: outputs, constant: constant, payable: payable)
}

fileprivate func parseFallback(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Fallback {
    let payable = abiRecord.stateMutability == "payable" || abiRecord.payable ?? false
    let constant = (abiRecord.constant ?? false) || abiRecord.stateMutability == "view" || abiRecord.stateMutability == "pure"

    return ABIv2.Element.Fallback(constant: constant, payable: payable)
}

fileprivate func parseConstructor(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Constructor {
    let inputs = try abiRecord.inputs?.map { try $0.parse() } ?? []

    let payable = (abiRecord.payable ?? false) || abiRecord.stateMutability == "payable"
    return ABIv2.Element.Constructor(inputs: inputs, constant: false, payable: payable)
}

fileprivate func parseEvent(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Event {
    let inputs = try abiRecord.inputs?.map { try $0.parseForEvent() } ?? []

    return ABIv2.Element.Event(name: abiRecord.name ?? "", inputs: inputs, anonymous: abiRecord.anonymous ?? false)
}

extension ABIv2.Input {
    func parse() throws -> ABIv2.Element.InOut {
        let parameterType = try ABIv2TypeParser.parseTypeString(type)
        if case .tuple = parameterType {
            let components = try components?.compactMap { return try $0.parse().type } ?? []
            let type = ABIv2.Element.ParameterType.tuple(types: components)

            return ABIv2.Element.InOut(name: name ?? "", type: type)
        } else {
            return ABIv2.Element.InOut(name: name ?? "", type: parameterType)
        }
    }

    func parseForEvent() throws -> ABIv2.Element.Event.Input {
        let parameterType = try ABIv2TypeParser.parseTypeString(type)
        return ABIv2.Element.Event.Input(name: name ?? "", type: parameterType, indexed: indexed ?? false)
    }
}

extension ABIv2.Output {
    func parse() throws -> ABIv2.Element.InOut {
        let parameterType = try ABIv2TypeParser.parseTypeString(type)
        switch parameterType {
        case .tuple:
            let components = try components?.compactMap { try $0.parse().type } ?? []
            let type = ABIv2.Element.ParameterType.tuple(types: components)
            return ABIv2.Element.InOut(name: name ?? "", type: type)
        case .array(type: let subtype, length: let length):
            switch subtype {
            case .tuple:
                let components = try self.components?.compactMap { try $0.parse().type } ?? []
                let nestedSubtype = ABIv2.Element.ParameterType.tuple(types: components)
                let properType = ABIv2.Element.ParameterType.array(type: nestedSubtype, length: length)

                return ABIv2.Element.InOut(name: name ?? "", type: properType)
            default:
                return ABIv2.Element.InOut(name: name ?? "", type: parameterType)
            }
        default:
            return ABIv2.Element.InOut(name: name ?? "", type: parameterType)
        }
    }
}
