import Foundation

/**
 A type-erased codable object.
 
 The `AnyCodable` type allows to encode and decode data prior to knowing the underlying type, delaying the type-matching
 to a later point in execution.
 
 When dealing with serialized JSON data structures where a single key can match to different types of values, the `AnyCodable`
 type can be used as a placeholder for `Any` while preserving the `Codable` conformance of the containing type. Another use case
 for the `AnyCodable` type is to facilitate the encoding of arrays of heterogeneous-typed values.
 
 You can call `get(_:)` to transform the underlying value back to the type you specify.
 */
public struct AnyCodable {

    public let value: Any

    private var dataEncoding: (() throws -> Data)?

    private var genericEncoding: ((Encoder) throws -> Void)?

    private init(_ value: Any) {
        self.value = value
    }

    /**
     Creates a type-erased codable value that wraps the given instance.
     
     - parameters:
        - codable: A codable value to wrap.
     */
    public init<C>(_ codable: C) where C: Codable {
        self.value = codable
        dataEncoding = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try encoder.encode(codable)
        }
        genericEncoding = { encoder in
            try codable.encode(to: encoder)
        }

    }

    /**
     Returns the underlying value, provided it matches the type spcified.
     
     Use this method to retrieve a strong-typed value, as long as it can be decoded from its underlying representation.
     
     - throws: If the value fails to decode to the specified type.
     
     - returns: The underlying value, if it can be decoded.
     
     ```
     let anyCodable = AnyCodable("a message")
     do {
         let value = try anyCodable.get(String.self)
         print(value)
     } catch {
         print("Error retrieving the value: \(error)")
     }
     ```
     */
    public func get<T: Codable>(_ type: T.Type) throws -> T {
        let valueData = try getDataRepresentation()
        return try JSONDecoder().decode(type, from: valueData)
    }

    /// A textual representation of the underlying encoded data. Returns an empty string if the type fails to encode.
    public var stringRepresentation: String {
        guard
            let valueData = try? getDataRepresentation(),
            let string = String(data: valueData, encoding: .utf8)
        else {
            return ""
        }
        return string
    }

    private func getDataRepresentation() throws -> Data {
        if let encodeToData = dataEncoding {
            return try encodeToData()
        } else {
            return try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        }
    }
}

extension AnyCodable: Equatable {

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        do {
            let lhsData = try lhs.getDataRepresentation()
            let rhsData = try rhs.getDataRepresentation()
            return lhsData == rhsData
        } catch {
            return false
        }
    }
}

extension AnyCodable: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(stringRepresentation)
    }
}

extension AnyCodable: CustomStringConvertible {

    public var description: String {
        let stringSelf = stringRepresentation
        let description = stringSelf.isEmpty ? "invalid data" : stringSelf
        return "AnyCodable: \"\(description)\""
    }
}

extension AnyCodable: Decodable, Encodable {

    struct CodingKeys: CodingKey {

        let stringValue: String
        let intValue: Int?

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = Int(stringValue)
        }
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            var result = [String: Any]()
            try container.allKeys.forEach { (key) throws in
                do {
                    let codable = try container.decode(AnyCodable.self, forKey: key)
                    result[key.stringValue] = codable.value
                } catch AnyCodableError.nullFound {
                    // Ignoring that key
                }
            }
            value = result
        } else if var container = try? decoder.unkeyedContainer() {
            var result = [Any]()
            while !container.isAtEnd {
                result.append(try container.decode(AnyCodable.self).value)
            }
            value = result
        } else if let container = try? decoder.singleValueContainer() {
            if let intVal = try? container.decode(Int.self) {
                value = intVal
            } else if let doubleVal = try? container.decode(Double.self) {
                value = doubleVal
            } else if let boolVal = try? container.decode(Bool.self) {
                value = boolVal
            } else if let stringVal = try? container.decode(String.self) {
                value = stringVal
            } else if container.decodeNil() {
                throw AnyCodableError.nullFound
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "The container contains nothing serializable.")
            }
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No data found in the decoder."))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if let encoding = genericEncoding {
            try encoding(encoder)
        } else if let array = value as? [Any] {
            var container = encoder.unkeyedContainer()
            for value in array {
                let decodable = AnyCodable(value)
                try container.encode(decodable)
            }
        } else if let dictionary = value as? [String: Any] {
            var container = encoder.container(keyedBy: CodingKeys.self)
            for (key, value) in dictionary {
                let codingKey = CodingKeys(stringValue: key)!
                let decodable = AnyCodable(value)
                try container.encode(decodable, forKey: codingKey)
            }
        } else if value is NSNull {
            // ignoring that key
        } else {
            var container = encoder.singleValueContainer()
            if let intVal = value as? Int {
                try container.encode(intVal)
            } else if let doubleVal = value as? Double {
                try container.encode(doubleVal)
            } else if let boolVal = value as? Bool {
                try container.encode(boolVal)
            } else if let stringVal = value as? String {
                try container.encode(stringVal)
            } else {
                throw EncodingError.invalidValue(value, EncodingError.Context.init(codingPath: [], debugDescription: "The value is not encodable."))
            }
        }
    }
}
