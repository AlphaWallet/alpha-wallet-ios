//
//  ContractAbiV1.swift
//  web3swift
//
//  Created by Alexander Vlasov on 10.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation
import BigInt

@available(*, deprecated)
struct ContractAbiV1: ContractRepresentable {
    var allEvents: [String] {
        return events.keys.flatMap { $0 }
    }
    var allMethods: [String] {
        return methods.keys.flatMap { $0 }
    }

    var address: EthereumAddress?
    var abi: [ABIElement]
    var methods: [String: ABIElement] {
        var toReturn: [String: ABIElement] = [:]
        for m in self.abi {
            switch m {
            case .function(let function):
                let name = function.name
                toReturn[name] = m
            default:
                continue
            }
        }
        return toReturn
    }

    var constructor: ABIElement? {
        var toReturn: ABIElement?
        for elem in self.abi {
            if toReturn != nil {
                break
            }
            switch elem {
            case .constructor:
                toReturn = elem
            default:
                continue
            }
        }

        return toReturn ?? ABIElement.constructor(ABIElement.Constructor.init(inputs: [], constant: false, payable: false))
    }

    var events: [String: ABIElement] {
        var toReturn: [String: ABIElement] = [:]
        for elem in self.abi {
            switch elem {
            case .event(let event):
                let name = event.name
                toReturn[name] = elem
            default:
                continue
            }
        }
        return toReturn
    }

    init(abi abiString: String, address: EthereumAddress? = nil) throws {
        do {
            let jsonData = Data(abiString.utf8)
            self.abi = try JSONDecoder().decode([ABIRecord].self, from: jsonData).map { try $0.parse() }
            self.address = address
        } catch {
            throw Web3.ContractError.abiError(.abiInvalid)
        }
    }

    init(abi: [ABIElement]) {
        self.abi = abi
    }

    init(abi: [ABIElement], at: EthereumAddress) {
        self.abi = abi
        self.address = at
    }

    func deploy(bytecode: Data, parameters: [AnyObject] = [AnyObject](), extraData: Data = Data(), options: Web3Options?) throws -> Transaction {
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
        var fullData = bytecode
        if encodedData != Data() {
            fullData.append(encodedData)
        } else if extraData != Data() {
            fullData.append(extraData)
        }

        return Transaction(gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: fullData)
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

        return Transaction(gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: extraData)
    }

    func methodData(_ method: String = "fallback", parameters: [AnyObject] = [], fallbackData: Data) throws -> Data {
        guard method != "fallback" else { return fallbackData }

        guard let abiElement = methods[method] else { throw Web3.ContractError.abiError(.methodNotFound(method)) }
        guard let data = abiElement.encodeParameters(parameters) else { throw Web3.ContractError.abiError(.encodeParamFailure(parameters)) }

        return data
    }

    func parseEvent(_ eventLog: EventLog) -> (eventName: String, eventData: [String: Any])? {
        for (eName, ev) in self.events {
            guard let parsed = ev.decodeReturnedLogs(eventLog) else { continue }
            return (eName, parsed)
        }

        return nil
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

    func testBloomForEventPrecence(eventName: String, bloom: EthereumBloomFilter) -> Bool? {
        return false
    }

    func decodeInputData(_ method: String, data: Data) -> [String: Any]? {
        return nil
    }

    func decodeInputData(_ data: Data) -> FunctionalCall? {
        return nil
    }

    func encodeTopicToGetLogs(eventName: String, filter: EventFilter) -> EventFilterParameters? {
        return nil
    }
}
