// Copyright © 2017-2018 Trust.
//
// This file is part of Trust. The full Trust copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

/// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md
import Foundation
import AlphaWalletABI
import BigInt

/// A struct represents EIP712 type tuple
public struct EIP712Type: Codable {
    let name: String
    let type: String
}

/// A struct represents EIP712 TypedData
public struct EIP712TypedData: Codable {
    public let types: [String: [EIP712Type]]
    public let primaryType: String
    public let domain: JSON
    public let message: JSON

    public var domainName: String {
        switch domain {
        case .object(let dictionary):
            switch dictionary["name"] {
            case .string(let value):
                return value
            case .array, .object, .number, .bool, .null, .none:
                return ""
            }
        case .array, .string, .number, .bool, .null:
            return ""
        }
    }

    public var server: RPCServer? {
        switch domain {
        case .object(let dictionary):
            switch dictionary["chainId"] {
            case .number(let value):
                if let value = Int(value.description) {
                    return RPCServer(chainIdOptional: value)
                }
                return nil
            case .object, .string, .array, .object, .bool, .null, .none:
                return nil
            }
        case .array, .string, .number, .bool, .null:
            return nil
        }
    }

    public var domainVerifyingContract: AlphaWallet.Address? {
        switch domain {
        case .object(let dictionary):
            switch dictionary["verifyingContract"] {
            case .string(let value):
                //We need it to be unchecked because test sites like to use 0xCcc..cc
                return AlphaWallet.Address(uncheckedAgainstNullAddress: value)
            case .array, .object, .number, .bool, .null, .none:
                return nil
            }
        case .array, .string, .number, .bool, .null:
            return nil
        }
    }
}

extension EIP712TypedData {
    /// Sign-able hash for an `EIP712TypedData`
    public var digest: Data {
        let data = Data(bytes: [0x19, 0x01]) + hashStruct(domain, type: "EIP712Domain") + hashStruct(message, type: primaryType)
        return Crypto.hash(data)
    }

    /// Recursively finds all the dependencies of a type
    public func findDependencies(primaryType: String, dependencies: Set<String> = Set<String>()) -> Set<String> {
        let primaryType = primaryType.dropTrailingSquareBrackets
        var found = dependencies
        guard !found.contains(primaryType),
            let primaryTypes = types[primaryType] else {
                return found
        }
        found.insert(primaryType)
        for type in primaryTypes {
            findDependencies(primaryType: type.type, dependencies: found)
                .forEach { found.insert($0) }
        }
        return found
    }

    /// Encode a type of struct
    func encodeType(primaryType: String) -> Data {
        var depSet = findDependencies(primaryType: primaryType)
        depSet.remove(primaryType)
        let sorted = [primaryType] + Array(depSet).sorted()
        let encoded = sorted.compactMap { type in
            guard let values = types[type] else { return nil }
            let param = values.map { "\($0.type) \($0.name)" }.joined(separator: ",")
            return "\(type)(\(param))"
        }.joined()
        return encoded.data(using: .utf8) ?? Data()
    }

    /// Encode an instance of struct
    ///
    /// Implemented with `ABIEncoder` and `ABIValue`
    func encodeData(data: JSON, type: String) -> Data {
        let encoder = ABIEncoder()
        var values: [ABIValue] = []
        do {
            if let valueTypes = types[type] {
                for field in valueTypes {
                    guard let value = data[field.name] else { continue }
                    if let encoded = try encodeField(value: value, type: field.type) {
                        values.append(encoded)
                    }
                }
            }
            try encoder.encode(tuple: values)
        } catch {
            //no op
        }
        return encoder.data
    }

    func encodeField(value: JSON, type: String) throws -> ABIValue? {
        if isStruct(type) {
            let nestEncoded = hashStruct(value, type: type)
            return try ABIValue(nestEncoded, type: .bytes(32))
            //Can't check for "[]" because we want to support static arrays: Type[n]
        } else if let indexOfOpenBracket = type.index(of: "["), type.hasSuffix("]"), case let .array(elements) = value {
            var encodedElements: Data = .init()
            let elementType = String(type[type.startIndex..<indexOfOpenBracket])
            for each in elements {
                if let value = try encodeField(value: each, type: elementType) {
                    let encoder = ABIEncoder()
                    try encoder.encode(value)
                    encodedElements += encoder.data
                }
            }
            return try ABIValue(Crypto.hash(encodedElements), type: .bytes(32))
        } else if let value = makeABIValue(data: value, type: type) {
            return value
        } else {
            return nil
        }
    }

    /// Helper func for `encodeData`
    private func makeABIValue(data: JSON?, type: String) -> ABIValue? {
        if type == "string", let value = data?.stringValue, let valueData = value.data(using: .utf8) {
            return try? ABIValue(Crypto.hash(valueData), type: .bytes(32))
        } else if type == "bytes", let value = data?.stringValue {
            let data = Data(_hex: value.drop0x)
            return try? ABIValue(Crypto.hash(data), type: .bytes(32))
        } else if type == "bool", let value = data?.boolValue {
            return try? ABIValue(value, type: .bool)
            //Using `AlphaWallet.Address(uncheckedAgainstNullAddress:)` instead of `AlphaWallet.Address(string:)` because EIP712v3 test pages like to use the contract 0xb...b which fails the burn address check
        } else if type == "address", let value = data?.stringValue, let address = AlphaWallet.Address(uncheckedAgainstNullAddress: value) {
            return try? ABIValue(address, type: .address)
        } else if type.starts(with: "uint") {
            let size = parseIntSize(type: type, prefix: "uint")

            guard size > 0 else { return nil }

            if let numberValue = data?.numberValue {
                switch numberValue {
                case let .int(value):
                    return try? ABIValue(value, type: .uint(bits: size))
                case let .double(value):
                    return try? ABIValue(Int(value), type: .uint(bits: size))
                }
            } else if let value = data?.stringValue,
                      let bigInt = BigUInt(value: value) {
                return try? ABIValue(bigInt, type: .uint(bits: size))
            }
        } else if type.starts(with: "int") {
            let size = parseIntSize(type: type, prefix: "int")

            guard size > 0 else { return nil }

            if let numberValue = data?.numberValue {
                switch numberValue {
                case let .int(value):
                    return try? ABIValue(value, type: .uint(bits: size))
                case let .double(value):
                    return try? ABIValue(Int(value), type: .uint(bits: size))
                }
            } else if let value = data?.stringValue,
                      let bigInt = BigInt(value: value) {
                return try? ABIValue(bigInt, type: .int(bits: size))
            }
        } else if type.starts(with: "bytes") {
            if let length = Int(type.dropFirst("bytes".count)), let value = data?.stringValue {
                if value.starts(with: "0x"),
                   let hex = Data(hexString: value) {
                    return try? ABIValue(hex, type: .bytes(length))
                } else {
                    return try? ABIValue(Data(bytes: Array(value.utf8)), type: .bytes(length))
                }
            }
        }
        return nil
    }

    /// Helper func for encoding uint / int types
    private func parseIntSize(type: String, prefix: String) -> Int {
        guard type.starts(with: prefix),
            let size = Int(type.dropFirst(prefix.count)) else {
            return -1
        }

        if size < 8 || size > 256 || size % 8 != 0 {
            return -1
        }
        return size
    }

    private func isStruct(_ fieldType: String) -> Bool {
        types[fieldType] != nil
    }

    private func hashStruct(_ data: JSON, type: String) -> Data {
        return Crypto.hash(typeHash(type) + encodeData(data: data, type: type))
    }

    private func typeHash(_ type: String) -> Data {
        return Crypto.hash(encodeType(primaryType: type))
    }
}

fileprivate extension String {
    var dropTrailingSquareBrackets: String {
        if let i = index(of: "["), hasSuffix("]") {
            return String(self[startIndex..<i])
        } else {
            return self
        }
    }
}

private extension BigInt {
    init?(value: String) {
        if value.starts(with: "0x") {
            self.init(String(value.dropFirst(2)), radix: 16)
        } else {
            self.init(value)
        }
    }
}

func abs(_ value: BigInt) -> BigInt {
    guard value.sign == .minus else { return value }

    return BigInt(sign: .plus, magnitude: value.magnitude)
}

private extension BigUInt {
    init?(value: String) {
        if value.starts(with: "0x") {
            self.init(String(value.dropFirst(2)), radix: 16)
        } else {
            self.init(value)
        }
    }
}

class Crypto {
    static func hash(_ data: Data) -> Data {
        return data.sha3(.keccak256)
    }
}

/// A JSON value representation. This is a bit more useful than the naïve `[String:Any]` type
/// for JSON values, since it makes sure only valid JSON values are present & supports `Equatable`
/// and `Codable`, so that you can compare values for equality and code and decode them into data
/// or strings.
extension EIP712TypedData {
    public enum NumberValue: Equatable, Codable, CustomStringConvertible {
        case double(Double)
        case int(Int)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let value = try? container.decode(Int.self) {
                self = .int(value)
            } else if let value = try? container.decode(Double.self) {
                self = .double(value)
            } else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value.")
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .int(value):
                try container.encode(value)
            case let .double(value):
                try container.encode(value)
            }
        }

        public var description: String {
            switch self {
            case let .int(value):
                return value.description
            case let .double(value):
                return value.description
            }
        }
    }

    public enum JSON: Equatable {
        case string(String)
        case number(EIP712TypedData.NumberValue)
        case object([String: JSON])
        case array([JSON])
        case bool(Bool)
        case null
    }
}

extension EIP712TypedData.JSON: Codable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .array(array):
            try container.encode(array)
        case let .object(object):
            try container.encode(object)
        case let .string(string):
            try container.encode(string)
        case let .number(number):
            try container.encode(number)
        case let .bool(bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let object = try? container.decode([String: EIP712TypedData.JSON].self) {
            self = .object(object)
        } else if let array = try? container.decode([EIP712TypedData.JSON].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(EIP712TypedData.NumberValue.self) {
            self = .number(number)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value.")
            )
        }
    }
}

extension EIP712TypedData.JSON: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .string(let str):
            return str.debugDescription
        case .number(let num):
            return num.description
        case .bool(let bool):
            return bool.description
        case .null:
            return "null"
        default:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            return try! String(data: encoder.encode(self), encoding: .utf8)!
        }
    }
}

extension EIP712TypedData.JSON {
    /// Return the string value if this is a `.string`, otherwise `nil`
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    /// Return the float value if this is a `.number`, otherwise `nil`
    var numberValue: EIP712TypedData.NumberValue? {
        if case .number(let value) = self {
            return value
        }
        return nil
    }

    /// Return the bool value if this is a `.bool`, otherwise `nil`
    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    /// Return the object value if this is an `.object`, otherwise `nil`
    var objectValue: [String: EIP712TypedData.JSON]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }

    /// Return the array value if this is an `.array`, otherwise `nil`
    var arrayValue: [EIP712TypedData.JSON]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    /// Return `true` if this is `.null`
    var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }

    /// If this is an `.array`, return item at index
    ///
    /// If this is not an `.array` or the index is out of bounds, returns `nil`.
    subscript(index: Int) -> EIP712TypedData.JSON? {
        if case .array(let arr) = self, arr.indices.contains(index) {
            return arr[index]
        }
        return nil
    }

    /// If this is an `.object`, return item at key
    subscript(key: String) -> EIP712TypedData.JSON? {
        if case .object(let dict) = self {
            return dict[key]
        }
        return nil
    }
}
