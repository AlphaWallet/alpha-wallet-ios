//
//  JSONRPC_2_0.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.11.2021.
//

import Foundation
import WalletConnectSwift

extension Int64: RequestID {}

extension JSONRPC_2_0.IDType {
    init(_ value: RequestID?) {
        switch value {
        case .none: self = .null
        case .some(let wrapped):
            if let value = wrapped as? String {
                self = .string(value)
            } else if let value = wrapped as? Int64 {
                self = .int(value)
            } else if let value = wrapped as? Int {
                self = .int(Int64(value))
            } else if let value = wrapped as? Double {
                self = .double(value)
            } else {
                preconditionFailure("Unknown Request ID IDType")
            }
        }
    }

    var requestID: RequestID? {
        switch self {
        case .string(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        case .null: return nil
        }
    }
}

extension Response {
    public convenience init<T: Encodable>(url: WCURL, value: T?, id: RequestID) throws {
        let result = try JSONRPC_2_0.Response.Payload.value(JSONRPC_2_0.ValueType(value))
        let response = JSONRPC_2_0.Response(result: result, id: JSONRPC_2_0.IDType(id))
        let jsonString = try response.json().string

        try self.init(url: url, jsonString: jsonString)
    }
}

internal extension JSONRPC_2_0.ValueType {
    init<T: Encodable>(_ value: T) throws {
        // Encodable types can be primitives (i.e. String), which encode to invalid JSON (root must be Array or Dict)
        let wrapped = try JSONEncoder.encoder().encode([value])
        let unwrapped = try JSONDecoder().decode([JSONRPC_2_0.ValueType].self, from: wrapped)
        self = unwrapped[0]
    }

    func decode<T: Decodable>(to type: T.Type) throws -> T {
        let data = try JSONEncoder.encoder().encode([self]) // wrap in array because values can be primitive types which is invalid json
        let result = try JSONDecoder().decode([T].self, from: data)
        return result[0]
    }
}

enum DataConversionError: Error {
    case stringToDataFailed
    case dataToStringFailed
}

internal enum JSONRPC_2_0 {
    struct JSON: Equatable, ExpressibleByStringInterpolation {
        var string: String

        init(_ text: String) {
            string = text
        }

        init(stringLiteral value: String) {
            self.init(value)
        }
    }

    enum IDType: Hashable, Codable {
        case string(String)
        case int(Int64)
        case double(Double)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let int = try? container.decode(Int64.self) {
                self = .int(int)
            } else if let double = try? container.decode(Double.self) {
                self = .double(double)
            } else if container.decodeNil() {
                self = .null
            } else {
                let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                    debugDescription: "Value is not a String, Number or Null")
                throw DecodingError.typeMismatch(IDType.self, context)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .double(let value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            }
        }
    }

    enum ValueType: Hashable, Codable {
        case object([String: ValueType])
        case array([ValueType])
        case string(String)
        case int(Int64)
        case double(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            if let keyedContainer = try? decoder.container(keyedBy: KeyType.self) {
                var result = [String: ValueType]()
                for key in keyedContainer.allKeys {
                    result[key.stringValue] = try keyedContainer.decode(ValueType.self, forKey: key)
                }
                self = .object(result)
            } else if var unkeyedContainer = try? decoder.unkeyedContainer() {
                var result = [ValueType]()
                while !unkeyedContainer.isAtEnd {
                    let value = try unkeyedContainer.decode(ValueType.self)
                    result.append(value)
                }
                self = .array(result)
            } else if let singleContainer = try? decoder.singleValueContainer() {
                if let string = try? singleContainer.decode(String.self) {
                    self = .string(string)
                } else if let int = try? singleContainer.decode(Int64.self) {
                    self = .int(int)
                } else if let double = try? singleContainer.decode(Double.self) {
                    self = .double(double)
                } else if let bool = try? singleContainer.decode(Bool.self) {
                    self = .bool(bool)
                } else if singleContainer.decodeNil() {
                    self = .null
                } else {
                    let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                        debugDescription: "Value is not a String, Number, Bool or Null")
                    throw DecodingError.typeMismatch(ValueType.self, context)
                }
            } else {
                let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                    debugDescription: "Did not match any container")
                throw DecodingError.typeMismatch(ValueType.self, context)
            }
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .object(let object):
                var container = encoder.container(keyedBy: KeyType.self)
                for (key, value) in object {
                    try container.encode(value, forKey: KeyType(stringValue: key)!)
                }
            case .array(let array):
                var container = encoder.unkeyedContainer()
                for value in array {
                    try container.encode(value)
                }
            case .string(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .int(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .double(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .bool(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .null:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }

        func jsonString() throws -> String {
            switch self {
            case .int, .double, .string, .bool, .null:
                // we have to wrap primitives into array because otherwise it is not a valid json
                let data = try JSONEncoder.encoder().encode([self])
                guard let string = String(data: data, encoding: .utf8) else {
                    throw DataConversionError.dataToStringFailed
                }
                assert(string.hasPrefix("["))
                assert(string.hasSuffix("]"))
                // now strip the json string of the wrapping array symbols '[' ']'
                return String(string.dropFirst(1).dropLast(1))
            case .object, .array:
                let data = try JSONEncoder.encoder().encode(self)
                guard let string = String(data: data, encoding: .utf8) else {
                    throw DataConversionError.dataToStringFailed
                }
                return string
            }
        }
    }

    struct KeyType: CodingKey {
        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = Int(stringValue)
        }

        var intValue: Int?

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = String(describing: intValue)
        }
    }

    /// https://www.jsonrpc.org/specification#request_object
    struct Request: Hashable, Codable {
        var jsonrpc = "2.0"
        var method: String
        var params: Params?
        var id: IDType?

        init(method: String, params: Params?, id: IDType?) {
            self.method = method
            self.params = params
            self.id = id
        }

        enum Params: Hashable, Codable {

            case positional([ValueType])
            case named([String: ValueType])

            init(from decoder: Decoder) throws {
                if let keyedContainer = try? decoder.container(keyedBy: KeyType.self) {
                    var result = [String: ValueType]()
                    for key in keyedContainer.allKeys {
                        result[key.stringValue] = try keyedContainer.decode(ValueType.self, forKey: key)
                    }
                    self = .named(result)
                } else if var unkeyedContainer = try? decoder.unkeyedContainer() {
                    var result = [ValueType]()
                    while !unkeyedContainer.isAtEnd {
                        let value = try unkeyedContainer.decode(ValueType.self)
                        result.append(value)
                    }
                    self = .positional(result)
                } else {
                    let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                        debugDescription: "Did not match any container")
                    throw DecodingError.typeMismatch(Params.self, context)
                }
            }

            func encode(to encoder: Encoder) throws {
                switch self {
                case .named(let object):
                    var container = encoder.container(keyedBy: KeyType.self)
                    for (key, value) in object {
                        try container.encode(value, forKey: KeyType(stringValue: key)!)
                    }
                case .positional(let array):
                    var container = encoder.unkeyedContainer()
                    for value in array {
                        try container.encode(value)
                    }
                }
            }
        }

        static func create(from json: JSONRPC_2_0.JSON) throws -> JSONRPC_2_0.Request {
            guard let data = json.string.data(using: .utf8) else {
                throw DataConversionError.stringToDataFailed
            }
            return try JSONDecoder().decode(JSONRPC_2_0.Request.self, from: data)
        }

        func json() throws -> JSONRPC_2_0.JSON {
            let data = try JSONEncoder.encoder().encode(self)
            guard let string = String(data: data, encoding: .utf8) else {
                throw DataConversionError.dataToStringFailed
            }
            return JSONRPC_2_0.JSON(string)
        }
    }

    struct Response: Hashable, Codable {
        var jsonrpc = "2.0"
        var result: Payload
        var id: IDType

        init(result: Payload, id: IDType) {
            self.result = result
            self.id = id
        }

        enum Payload: Hashable, Codable {
            case value(ValueType)
            case error(ErrorPayload)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let error = try? container.decode(ErrorPayload.self) {
                    self = .error(error)
                } else if let value = try? container.decode(ValueType.self) {
                    self = .value(value)
                } else if container.decodeNil() {
                    self = .value(.null)
                } else {
                    let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                        debugDescription: "Payload is neither error, nor JSON value")
                    throw DecodingError.typeMismatch(ValueType.self, context)
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .value(let value):
                    try container.encode(value)
                case .error(let value):
                    try container.encode(value)
                }
            }

            /// https://www.jsonrpc.org/specification#error_object
            struct ErrorPayload: Hashable, Codable {

                var code: Code
                var message: String
                var data: ValueType?

                init(code: Code, message: String, data: ValueType?) {
                    self.code = code
                    self.message = message
                    self.data = data
                }

                struct Code: Hashable, Codable {

                    var code: Int

                    enum InitializationError: String, Error {
                        case codeAlreadyReservedForPredefinedErrors
                    }

                    static let invalidJSON = Code(code: -32_700)
                    static let invalidRequest = Code(code: -32_600)
                    static let methodNotFound = Code(code: -32_601)
                    static let invalidParams = Code(code: -32_602)
                    static let internalError = Code(code: -32_603)

                    init(_ code: Int) throws {
                        let forbiddenPredefinedRange = (-32768 ... -32000)
                        let allowedServerErrorsRange = (-32099 ... -32000)
                        let allowedPredefinedErrors = [-32700, -32600, -32601, -32602, -32603]

                        if forbiddenPredefinedRange.contains(code) &&
                            !(allowedServerErrorsRange.contains(code) || allowedPredefinedErrors.contains(code)) {
                            throw InitializationError.codeAlreadyReservedForPredefinedErrors
                        }
                        self.init(code: code)
                    }

                    init(code: Int) {
                        self.code = code
                    }

                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        code = try container.decode(Int.self)
                    }

                    func encode(to encoder: Encoder) throws {
                        var container = encoder.singleValueContainer()
                        try container.encode(code)
                    }
                }

            }
        }

        static func create(from json: JSONRPC_2_0.JSON) throws -> JSONRPC_2_0.Response {
            guard let data = json.string.data(using: .utf8) else {
                throw DataConversionError.stringToDataFailed
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .custom { codingKeys in
                let lastKey = codingKeys.last!
                guard lastKey.intValue == nil else { return lastKey }
                let stringValue = lastKey.stringValue == "error" ? "result" : lastKey.stringValue
                return JSONRPC_2_0.KeyType(stringValue: stringValue)!
            }
            return try decoder.decode(JSONRPC_2_0.Response.self, from: data)
        }

        func json() throws -> JSONRPC_2_0.JSON {
            let encoder = JSONEncoder.encoder()
            if case Payload.error(_) = result {
                encoder.keyEncodingStrategy = .custom { codingKeys in
                    let lastKey = codingKeys.last!
                    guard lastKey.intValue == nil else { return lastKey }
                    let stringValue = lastKey.stringValue == "result" ? "error" : lastKey.stringValue
                    return JSONRPC_2_0.KeyType(stringValue: stringValue)!
                }
            }
            let data = try encoder.encode(self)
            guard let string = String(data: data, encoding: .utf8) else {
                throw DataConversionError.dataToStringFailed
            }
            return JSONRPC_2_0.JSON(string)
        }
    }
}

extension JSONEncoder {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
