//
//  ContractABIv2.swift
//  web3swift
//
//  Created by Alexander Vlasov on 04.04.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt

public struct Contract: ContractRepresentable {
    private var contract: ContractRepresentable

    public var address: EthereumAddress? {
        get { return contract.address }
        set { contract.address = newValue }
    }

    public var allMethods: [String] { contract.allEvents }
    public var allEvents: [String] { contract.allEvents }

    public init(abi: String, address: EthereumAddress? = nil) throws {
        do {
            contract = try ContractAbiV2(abi: abi, address: address)
        } catch {
            contract = try ContractAbiV1(abi: abi, address: address)
        }
    }

    func deploy(bytecode: Data, parameters: [AnyObject], extraData: Data, options: Web3Options?) throws -> Transaction {
        try contract.deploy(bytecode: bytecode, parameters: parameters, extraData: extraData, options: options)
    }

    func method(_ method: String, parameters: [AnyObject], extraData: Data, options: Web3Options?) throws -> Transaction {
        try contract.method(method, parameters: parameters, extraData: extraData, options: options)
    }

    public func methodData(_ method: String = "fallback", parameters: [AnyObject] = [], fallbackData: Data = Data()) throws -> Data {
        try contract.methodData(method, parameters: parameters, fallbackData: fallbackData)
    }

    public func decodeReturnData(_ method: String, data: Data) -> [String: Any]? {
        return contract.decodeReturnData(method, data: data)
    }

    public func decodeInputData(_ method: String, data: Data) -> [String: Any]? {
        contract.decodeInputData(method, data: data)
    }

    public func decodeInputData(_ data: Data) -> FunctionalCall? {
        contract.decodeInputData(data)
    }

    public func parseEvent(_ eventLog: EventLog) -> (eventName: String, eventData: [String: Any])? {
        contract.parseEvent(eventLog)
    }

    public func testBloomForEventPrecence(eventName: String, bloom: EthereumBloomFilter) -> Bool? {
        contract.testBloomForEventPrecence(eventName: eventName, bloom: bloom)
    }

    public func encodeTopicToGetLogs(eventName: String, filter: EventFilter) -> EventFilterParameters? {
        contract.encodeTopicToGetLogs(eventName: eventName, filter: filter)
    }
}

struct ContractAbiV2: ContractRepresentable {

    var allEvents: [String] {
        return events.keys.compactMap { $0 }
    }

    var allMethods: [String] {
        return methods.keys.compactMap { $0 }
    }

    var address: EthereumAddress?
    var abi: [ABIv2.Element]

    var methods: [String: ABIv2.Element] {
        var toReturn: [String: ABIv2.Element] = [:]
        for m in self.abi {
            switch m {
            case .function(let function):
                guard let name = function.name else { continue }
                toReturn[name] = m
            default:
                continue
            }
        }
        return toReturn
    }

    var constructor: ABIv2.Element? {
        var toReturn: ABIv2.Element?
        for element in self.abi {
            if toReturn != nil {
                break
            }
            switch element {
            case .constructor:
                toReturn = element
            default:
                continue
            }
        }
        if toReturn == nil {
            return ABIv2.Element.constructor(ABIv2.Element.Constructor.init(inputs: [], constant: false, payable: false))
        }
        return toReturn
    }

    var events: [String: ABIv2.Element.Event] {
        var toReturn: [String: ABIv2.Element.Event] = [:]
        for element in self.abi {
            switch element {
            case .event(let event):
                let name = event.name
                toReturn[name] = event
            default:
                continue
            }
        }
        return toReturn
    }

    init(abi: String, address: EthereumAddress? = nil) throws {
        do {
            let json = Data(abi.utf8)
            self.abi = try JSONDecoder().decode([ABIv2.Record].self, from: json).map { try $0.parse() }
            self.address = address
        } catch {
            throw Web3.ContractError.abiError(.abiInvalid)
        }
    }

    init(abi: [ABIv2.Element]) {
        self.abi = abi
    }

    init(abi: [ABIv2.Element], at: EthereumAddress) {
        self.abi = abi
        self.address = at
    }

    func deploy(bytecode: Data, parameters: [AnyObject] = [], extraData: Data = Data(), options: Web3Options?) throws -> Transaction {
        let to: EthereumAddress = EthereumAddress.contractDeploymentAddress()
        var gasLimit: BigUInt
        if let gasInOptions = options?.gasLimit {
            gasLimit = gasInOptions
        } else {
            throw Web3.ContractError.gasLimitNotFound
        }

        var gasPrice: BigUInt
        if let gasPriceInOptions = options?.gasPrice {
            gasPrice = gasPriceInOptions
        } else {
            throw Web3.ContractError.gasPriceNotFound
        }

        var value: BigUInt
        if let valueInOptions = options?.value {
            value = valueInOptions
        } else {
            value = BigUInt(0)
        }
        guard let constructor = self.constructor else { throw Web3.ContractError.abiError(.constructorNotFound) }
        guard let encodedData = constructor.encodeParameters(parameters) else { throw Web3.ContractError.abiError(.encodeParamFailure(parameters)) }
        var data = bytecode
        if encodedData != Data() {
            data.append(encodedData)
        } else if extraData != Data() {
            data.append(extraData)
        }

        return Transaction(gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: data)
    }

    func method(_ method: String = "fallback", parameters: [AnyObject] = [], extraData: Data = Data(), options: Web3Options?) throws -> Transaction {
        var to: EthereumAddress
        if let address = address {
            to = address
        } else if let address = options?.to, address.isValid {
            to = address
        } else {
            throw Web3.ContractError.toNotFound
        }

        var gasLimit: BigUInt
        if let gasInOptions = options?.gasLimit {
            gasLimit = gasInOptions
        } else {
            throw Web3.ContractError.gasLimitNotFound
        }

        var gasPrice: BigUInt
        if let gasPriceInOptions = options?.gasPrice {
            gasPrice = gasPriceInOptions
        } else {
            throw Web3.ContractError.gasPriceNotFound
        }

        var value: BigUInt
        if let valueInOptions = options?.value {
            value = valueInOptions
        } else {
            value = BigUInt(0)
        }

        let data = try methodData(method, parameters: parameters, fallbackData: extraData)

        return Transaction(gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: data)
    }

    func methodData(_ method: String = "fallback", parameters: [AnyObject] = [], fallbackData: Data = Data()) throws -> Data {
        guard method != "fallback" else { return fallbackData }

        guard let abiElement = methods[method] else { throw Web3.ContractError.abiError(.methodNotFound(method)) }
        guard let data = abiElement.encodeParameters(parameters) else { throw Web3.ContractError.abiError(.encodeParamFailure(parameters)) }

        return data
    }

    func parseEvent(_ eventLog: EventLog) -> (eventName: String, eventData: [String: Any])? {
        for (eName, ev) in self.events {
            if !ev.anonymous {
                if eventLog.topics[0] != ev.topic {
                    continue
                } else {
                    if let parsed = ev.decodeReturnedLogs(eventLog) {
                        return (eName, parsed)
                    }
                }
            } else {
                if let parsed = ev.decodeReturnedLogs(eventLog) {
                    return (eName, parsed)
                }
            }
        }
        return nil
    }

    func testBloomForEventPrecence(eventName: String, bloom: EthereumBloomFilter) -> Bool? {
        guard let event = events[eventName] else { return nil }
        if event.anonymous {
            return true
        }
        return bloom.test(topic: event.topic)
    }

    func decodeReturnData(_ method: String, data: Data) -> [String: Any]? {
        guard method != "fallback" else {
            let resultHex = data.toHexString().addHexPrefix()
            return ["result": resultHex as Any]
        }

        guard let function = methods[method] else { return nil }
        guard case .function = function else { return nil }

        return function.decodeReturnData(data)
    }

    func decodeInputData(_ method: String, data: Data) -> [String: Any]? {
        guard method != "fallback" else { return nil }

        guard let function = methods[method] else { return nil }
        switch function {
        case .function, .constructor:
            return function.decodeInputData(data)
        default:
            return nil
        }
    }

    func decodeInputData(_ data: Data) -> FunctionalCall? {
        guard data.count % 32 == 4 else { return nil }
        let signature = data[0..<4]
        let functions = self.abi.filter { element -> Bool in
            switch element {
            case .function(let function):
                return function.methodEncoding == signature
            default:
                return false
            }
        }

        guard functions.count == 1 else { return nil }
        let function = functions[0]

        switch function {
        case .function(let f):
            let decoded = function.decodeInputData(Data(data[4 ..< data.count]))
            return FunctionalCall(name: f.name, signature: f.methodString, params: decoded)
        case .constructor, .fallback, .event:
            return nil
        }
    }

    func encodeTopicToGetLogs(eventName: String, filter: EventFilter) -> EventFilterParameters? {
        guard let event = events[eventName] else { return nil }

        var topics: [[String?]?] = [[event.topic.toHexString().addHexPrefix()]]

        if let parameterFilters = filter.parameterFilters {
            var lastNonemptyFilter = -1
            for i in 0 ..< parameterFilters.count {
                let filterValue = parameterFilters[i]
                if filterValue != nil {
                    lastNonemptyFilter = i
                }
            }
            if lastNonemptyFilter != -1 {
                guard lastNonemptyFilter <= event.inputs.count else { return nil }
                for i in 0 ... lastNonemptyFilter {
                    let filterValues = parameterFilters[i]
                    if filterValues != nil {
                        var isFound = false
                        var targetIndexedPosition = i
                        for j in 0 ..< event.inputs.count where event.inputs[j].indexed {
                            if targetIndexedPosition == 0 {
                                isFound = true
                                break
                            }
                            targetIndexedPosition -= 1
                        }

                        if !isFound { return nil }
                    }

                    if filterValues == nil {
                        topics.append(nil as [String?]?)
                        continue
                    }
                    var encodings = [String]()
                    for val in filterValues! {
                        guard let enc = val.eventFilterEncoded() else { return nil }
                        encodings.append(enc)
                    }
                    topics.append(encodings)
                }
            }
        }

        var preEncoding = filter.rpcPreEncode()
        preEncoding.topics = topics

        return preEncoding
    }
}
