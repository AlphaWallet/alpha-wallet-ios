// Copyright © 2017-2018 Trust.
//
// This file is part of Trust. The full Trust copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation
import AlphaWalletAddress
import BigInt
import TrustKeystore

/// Encodes fields according to Ethereum's Application Binary Interface Specification
///
/// - SeeAlso: https://solidity.readthedocs.io/en/develop/abi-spec.html
public final class ABIEncoder {
    static let encodedIntSize = 32

    /// Encoded data
    public var data = Data()

    /// Creates an `ABIEncoder`.
    public init() {}

    /// Encodes an `ABIValue`
    public func encode(_ value: ABIValue) throws {
        switch value {
        case .uint(_, let value):
            try encode(value)
        case .int(_, let value):
            try encode(value)
        case .address(let address):
            try encode(address)
        case .address2(let address):
            try encode(address)
        case .bool(let value):
            try encode(value)
        case .fixed(_, _, let value):
            try encode(value)
        case .ufixed(_, _, let value):
            try encode(value)
        case .bytes(let data):
            try encode(data, static: true)
        case .function(let f, let args):
            try encode(signature: f.description)
            try encode(tuple: args)
        case .array(let type, let array):
            precondition(!array.contains(where: { $0.type != type }), "Array can only contain values of type \(type)")
            try encode(tuple: array)
        case .dynamicBytes(let data):
            try encode(data, static: false)
        case .string(let string):
            try encode(string)
        case .dynamicArray(let type, let array):
            precondition(!array.contains(where: { $0.type != type }), "Array can only contain values of type \(type)")
            try encode(array.count)
            try encode(tuple: array)
        case .tuple(let array):
            try encode(tuple: array)
        }
    }

    /// Encodes a tuple
    public func encode(tuple: [ABIValue]) throws {
        var headSize = 0
        for subvalue in tuple {
            if subvalue.isDynamic {
                headSize += 32
            } else {
                headSize += subvalue.length
            }
        }

        var dynamicOffset = 0
        for subvalue in tuple {
            if subvalue.isDynamic {
                try encode(headSize + dynamicOffset)
                dynamicOffset += subvalue.length
            } else {
                try encode(subvalue)
            }
        }

        for subvalue in tuple where subvalue.isDynamic {
            try encode(subvalue)
        }
    }

    /// Encodes a function call
    public func encode(function: Function, arguments: [Any]) throws {
        try encode(signature: function.description)
        try encode(tuple: function.castArguments(arguments))
    }

    /// Encodes a boolean field.
    public func encode(_ value: Bool) throws {
        data.append(Data(repeating: 0, count: ABIEncoder.encodedIntSize - 1))
        data.append(value ? 1 : 0)
    }

    /// Encodes an unsigned integer.
    public func encode(_ value: UInt) throws {
        try encode(BigUInt(value))
    }

    /// Encodes a `BigUInt` field.
    ///
    /// - Throws: `ABIError.integerOverflow` if the value has more than 256 bits.
    public func encode(_ value: BigUInt) throws {
        let valueData = value.serialize()
        if valueData.count > ABIEncoder.encodedIntSize {
            throw ABIError.integerOverflow
        }

        data.append(Data(repeating: 0, count: ABIEncoder.encodedIntSize - valueData.count))
        data.append(valueData)
    }

    /// Encodes a signed integer.
    public func encode(_ value: Int) throws {
        try encode(BigInt(value))
    }

    /// Encodes a `BigInt` field.
    ///
    /// - Throws: `ABIError.integerOverflow` if the value has more than 256 bits.
    public func encode(_ value: BigInt) throws {
        let valueData = twosComplement(value)
        if valueData.count > ABIEncoder.encodedIntSize {
            throw ABIError.integerOverflow
        }

        if value.sign == .plus {
            data.append(Data(repeating: 0, count: ABIEncoder.encodedIntSize - valueData.count))
        } else {
            data.append(Data(repeating: 255, count: ABIEncoder.encodedIntSize - valueData.count))
        }
        data.append(valueData)
    }

    // Computes the two's complement for a `BigInt` with 256 bits
    private func twosComplement(_ value: BigInt) -> Data {
        let magnitude = value.magnitude
        if value.sign == .plus {
            return magnitude.serialize()
        }

        let serializedLength = magnitude.serialize().count
        let max = BigUInt(1) << (serializedLength * 8)
        return (max - magnitude).serialize()
    }

    /// Encodes a static or dynamic byte array
    public func encode(_ bytes: Data, static: Bool) throws {
        if !`static` {
            try encode(bytes.count)
        }
        let padding = ((bytes.count + 31) / 32) * 32 - bytes.count
        data.append(bytes)
        data.append(Data(repeating: 0, count: padding))
    }

    //TODO change this to use AlphaWallet.Address?
    /// Encodes an address
    public func encode(_ address: Address) throws {
        let padding = ((address.data.count + 31) / 32) * 32 - address.data.count
        data.append(Data(repeating: 0, count: padding))
        data.append(address.data)
    }

    public func encode(_ address: AlphaWallet.Address) throws {
        let padding = ((address.data.count + 31) / 32) * 32 - address.data.count
        data.append(Data(repeating: 0, count: padding))
        data.append(address.data)
    }

    /// Encodes a string
    ///
    /// - Throws: `ABIError.invalidUTF8String` if the string cannot be encoded as UTF8.
    public func encode(_ string: String) throws {
        guard let bytes = string.data(using: .utf8) else {
            throw ABIError.invalidUTF8String
        }
        try encode(bytes, static: false)
    }

    /// Encodes a function signature
    public func encode(signature: String) throws {
        data.append(try ABIEncoder.encode(signature: signature))
    }

    /// Encodes a function signature
    public static func encode(signature: String) throws -> Data {
        guard let bytes = signature.data(using: .utf8) else {
            throw ABIError.invalidUTF8String
        }
        let hash = bytes.sha3(.keccak256)
        return hash[0..<4]
    }
}

