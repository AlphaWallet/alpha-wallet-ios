//
//  DecodedFunctionCall+Decode.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2021.
//

import EthereumAddress
import EthereumABI
import BigInt

//NOTE: extracted to separated file to avoid missunderstanding with EthereumAddress address, web3swift and EthereumAddress contains the same struct for EthereumAddress. it causes types comparison issue
extension DecodedFunctionCall {

    private static func contract(abi: Data) -> [ABI.Element]? {
        do {
            let jsonDecoder = JSONDecoder()
            let abi = try jsonDecoder.decode([ABI.Record].self, from: abi)
            return try abi.map { (record) -> ABI.Element in
                return try record.parse()
            }
        } catch {
            return nil
        }
    }

    static func decode(data: Data, abi: Data) -> DecodedFunctionCall? {
        guard let contract = contract(abi: abi), data.count > 4 else { return nil }

        let functionToResearch = data[0..<4].hex()
        for element in contract {
            switch element {
            case .function(let function):
                guard let functionName = function.name else { return nil }

                if functionToResearch == function.methodEncoding.hex(), let inputs = element.decodeInputData(data) {
                    //NOTE: perform filter for response input data to remove duplicated values from dictionary
                    let arguments = inputs.compactMap { value -> (type: ABIType, value: AnyObject)? in
                        if let inputParam = function.inputs.first(where: { $0.name == value.key }), let type = ABIType(abiParam: inputParam.type) {
                            return (type, value.value as AnyObject)
                        }
                        return nil
                    }

                    let functionType = DecodedFunctionCall.FunctionType(name: functionName, arguments: arguments)
                    return DecodedFunctionCall(name: functionName, arguments: arguments, type: functionType)
                }
            case .constructor, .event, .fallback:
                break
            }
        }

        return nil
    }
}

extension ABIType {
    init?(abiParam param: ABI.Element.ParameterType) {
        switch param {
        case .uint(let bits):
            self = .uint(bits: Int(bits))
        case .int(let bits):
            self = .int(bits: Int(bits))
        case .address:
            self = .address
        case .function:
            return nil
        case .bool:
            self = .bool
        case .bytes(let length):
            self = .bytes(Int(length))
        case .array(let type, let length):
            guard let t = ABIType(abiParam: type) else { return nil }
            self = .array(t, Int(length))
        case .dynamicBytes:
            self = .dynamicBytes
        case .string:
            self = .string
        case .tuple(let types):
            let values = types.compactMap { ABIType.init(abiParam: $0) }
            self = .tuple(values)
        }
    }
}

extension DecodedFunctionCall.FunctionType {
    init(name: String, arguments: [(type: ABIType, value: AnyObject)]) {
        if name == DecodedFunctionCall.erc20Transfer.name, let address: EthereumAddress = arguments.get(type: .address, atIndex: 0), let value: BigUInt = arguments.get(type: .uint(bits: 256), atIndex: 1) {
            self = .erc20Transfer(recipient: AlphaWallet.Address.ethereumAddress(eip55String: address.address), value: value)
        } else if name == DecodedFunctionCall.erc20Approve.name, let address: EthereumAddress = arguments.get(type: .address, atIndex: 0), let value: BigUInt = arguments.get(type: .uint(bits: 256), atIndex: 1) {
            self = .erc20Approve(spender: AlphaWallet.Address.ethereumAddress(eip55String: address.address), value: value)
        } else if name == DecodedFunctionCall.erc1155SafeTransfer.name, let address: EthereumAddress = arguments.get(type: .address, atIndex: 0) {
            self = .erc1155SafeTransfer(spender: AlphaWallet.Address.ethereumAddress(eip55String: address.address))
        } else if name == DecodedFunctionCall.erc1155SafeBatchTransfer.name, let address: EthereumAddress = arguments.get(type: .address, atIndex: 0) {
            self = .erc1155SafeBatchTransfer(spender: AlphaWallet.Address.ethereumAddress(eip55String: address.address))
        } else {
            self = .others
        }
    }
}

private extension Collection where Element == (type: ABIType, value: AnyObject) {
    func get<T>(type: ABIType, atIndex index: Self.Index) -> T? {
        guard indices.contains(index) else { return nil }
        let element = self[index]
        if element.type == type {
            return element.value as? T
        } else {
            return nil
        }
    }
}
