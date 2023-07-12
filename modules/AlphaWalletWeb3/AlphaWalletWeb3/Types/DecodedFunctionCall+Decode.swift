//
//  DecodedFunctionCall+Decode.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2021.
//

import AlphaWalletABI
import AlphaWalletAddress
import AlphaWalletCore
import BigInt
import EthereumABI

extension FunctionCall.Argument {
    init(type: ABIType, anyValue: Any?) {
        self.type = type
        if let address = AlphaWallet.Address(possibleAddress: anyValue) {
            self.value = address
        } else {
            self.value = anyValue
        }
    }
}

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

    public static func decode(data: Data, abi: String) -> DecodedFunctionCall? {
        decode(data: data, abi: Data(abi.utf8))
    }

    public static func decode(data: Data, abi: Data) -> DecodedFunctionCall? {
        guard let contract = contract(abi: abi), data.count > 4 else { return nil }

        let functionToResearch = data[0..<4].hex()
        for element in contract {
            switch element {
            case .function(let function):
                guard let functionName = function.name else { return nil }

                if functionToResearch == function.methodEncoding.hex(), let inputs = element.decodeInputData(data) {
                    let arguments: [FunctionCall.Argument] = function.inputs.compactMap { inputParam in
                        let value = inputs[inputParam.name]
                        if let type = ABIType(abiParam: inputParam.type) {
                            return FunctionCall.Argument(type: type, anyValue: value)
                        } else {
                            return nil
                        }
                    }
                    //TODO check isArgCountMatches too:
                    _ = inputs.count * 2 == function.inputs.count
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
            let values = types.compactMap { ABIType(abiParam: $0) }
            self = .tuple(values)
        }
    }
}

extension DecodedFunctionCall.FunctionType {
    init(name: String, arguments: [FunctionCall.Argument]) {
        if name == DecodedFunctionCall.erc20Transfer.name, let address: AlphaWallet.Address = arguments.get(type: .address, atIndex: 0), let value: BigUInt = arguments.get(type: .uint(bits: 256), atIndex: 1) {
            self = .erc20Transfer(recipient: address, value: value)
        } else if name == DecodedFunctionCall.erc20Approve.name, let address: AlphaWallet.Address = arguments.get(type: .address, atIndex: 0), let value: BigUInt = arguments.get(type: .uint(bits: 256), atIndex: 1) {
            self = .erc20Approve(spender: address, value: value)
        } else if name == DecodedFunctionCall.erc721ApproveAll.name, let address: AlphaWallet.Address = arguments.get(type: .address, atIndex: 0), let value: Bool = arguments.get(type: .bool, atIndex: 1) {
            self = .erc721ApproveAll(spender: address, value: value)
        } else if name == DecodedFunctionCall.erc1155SafeTransfer.name, let address: AlphaWallet.Address = arguments.get(type: .address, atIndex: 0) {
            self = .erc1155SafeTransfer(spender: address)
        } else if name == DecodedFunctionCall.erc1155SafeBatchTransfer.name, let address: AlphaWallet.Address = arguments.get(type: .address, atIndex: 0) {
            self = .erc1155SafeBatchTransfer(spender: address)
        } else {
            self = .others(name: name, arguments: arguments)
        }
    }
}

private extension Collection where Element == FunctionCall.Argument {
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

private extension AlphaWallet.Address {
    public init?(possibleAddress: Any?) {
        if let address = possibleAddress as? AlphaWallet.Address {
            self = address
        } else if let address = possibleAddress as? EthereumAddress_fromEthereumAddressPod {
            self = .ethereumAddress(eip55String: address.address)
        } else if let address = possibleAddress as? AlphaWalletWeb3.EthereumAddress {
            self = .ethereumAddress(eip55String: address.address)
        } else {
            return nil
        }
    }
}
