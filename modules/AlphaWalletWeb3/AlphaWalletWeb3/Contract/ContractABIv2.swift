//
//  ContractABIv2.swift
//  web3swift
//
//  Created by Alexander Vlasov on 04.04.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt

public struct ContractV2: ContractProtocol {
    
    public var allEvents: [String] {
        return events.keys.compactMap { $0 }
    }
    
    public var allMethods: [String] {
        return methods.keys.compactMap { $0 }
    }
    
    public struct EventFilter {
        public var parameterName: String
        public var parameterValues: [AnyObject]
    }
    
    public var address: EthereumAddress?
    var abi: [ABIv2.Element]

    public var methods: [String: ABIv2.Element] {
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
    
    public var constructor: ABIv2.Element? {
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
    
    public var events: [String: ABIv2.Element.Event] {
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
    
    public var options: Web3Options? = Web3Options.defaultOptions()
    
    public init(abi: String, address: EthereumAddress? = nil) throws {
        do {
            guard let json = abi.data(using: .utf8) else { throw Web3.ContractError.abiError(.abiInvalid) }

            self.abi = try JSONDecoder().decode([ABIv2.Record].self, from: json).map { try $0.parse() }
            self.address = address
        } catch {
            throw Web3.ContractError.abiError(.abiInvalid)
        }
    }
    
    public init(abi: [ABIv2.Element]) {
        self.abi = abi
    }
    
    public init(abi: [ABIv2.Element], at: EthereumAddress) {
        self.abi = abi
        self.address = at
    }
    
    public func deploy(bytecode: Data, parameters: [AnyObject] = [], extraData: Data = Data(), options: Web3Options?) throws -> EthereumTransaction {
        let to: EthereumAddress = EthereumAddress.contractDeploymentAddress()
        let mergedOptions = Web3Options.merge(self.options, with: options)
        var gasLimit: BigUInt
        if let gasInOptions = mergedOptions?.gasLimit {
            gasLimit = gasInOptions
        } else {
            throw Web3.ContractError.gasLimitNotFound
        }
        
        var gasPrice: BigUInt
        if let gasPriceInOptions = mergedOptions?.gasPrice {
            gasPrice = gasPriceInOptions
        } else {
            throw Web3.ContractError.gasPriceNotFound
        }
        
        var value: BigUInt
        if let valueInOptions = mergedOptions?.value {
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

        return EthereumTransaction(gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: data)
    }
    
    public func method(_ method: String = "fallback", parameters: [AnyObject] = [], extraData: Data = Data(), options: Web3Options?) throws -> EthereumTransaction {
        var to: EthereumAddress
        let mergedOptions = Web3Options.merge(self.options, with: options)
        if let address = address {
            to = address
        } else if let toAddress = mergedOptions?.to, toAddress.isValid {
            to = toAddress
        } else {
            throw Web3.ContractError.toNotFound
        }
        
        var gasLimit: BigUInt
        if let gasInOptions = mergedOptions?.gasLimit {
            gasLimit = gasInOptions
        } else {
            throw Web3.ContractError.gasLimitNotFound
        }
        
        var gasPrice: BigUInt
        if let gasPriceInOptions = mergedOptions?.gasPrice {
            gasPrice = gasPriceInOptions
        } else {
            throw Web3.ContractError.gasPriceNotFound
        }
        
        var value: BigUInt
        if let valueInOptions = mergedOptions?.value {
            value = valueInOptions
        } else {
            value = BigUInt(0)
        }
        
        if method == "fallback" {
            return EthereumTransaction(gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: extraData)
        } else {
            guard let abiElement = methods[method] else { throw Web3.ContractError.abiError(.methodNotFound(method)) }
            guard let data = abiElement.encodeParameters(parameters) else { throw Web3.ContractError.abiError(.encodeParamFailure(parameters)) }

            return EthereumTransaction(gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: data)
        }
    }
    
    public func parseEvent(_ eventLog: EventLog) -> (eventName: String?, eventData: [String: Any]?) {
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
        return (nil, nil)
    }
    
    public func testBloomForEventPrecence(eventName: String, bloom: EthereumBloomFilter) -> Bool? {
        guard let event = events[eventName] else { return nil }
        if event.anonymous {
            return true
        }
        return bloom.test(topic: event.topic)
    }
    
    public func decodeReturnData(_ method: String, data: Data) -> [String: Any]? {
        guard method != "fallback" else { return [:] }

        guard let function = methods[method] else { return nil }
        guard case .function = function else { return nil }
        return function.decodeReturnData(data)
    }
    
    public func decodeInputData(_ method: String, data: Data) -> [String: Any]? {
        guard method != "fallback" else { return nil }

        guard let function = methods[method] else { return nil }
        switch function {
        case .function:
            return function.decodeInputData(data)
        case .constructor:
            return function.decodeInputData(data)
        default:
            return nil
        }
    }
    
    public func decodeInputData(_ data: Data) -> [String: Any]? {
        guard data.count % 32 == 4 else { return nil }
        let methodSignature = data[0..<4]
        let foundFunction = self.abi.filter { (m) -> Bool in
            switch m {
            case .function(let function):
                return function.methodEncoding == methodSignature
            default:
                return false
            }
        }
        guard foundFunction.count == 1 else { return nil }
        
        return foundFunction[0].decodeInputData(Data(data[4 ..< data.count]))
    }
}
