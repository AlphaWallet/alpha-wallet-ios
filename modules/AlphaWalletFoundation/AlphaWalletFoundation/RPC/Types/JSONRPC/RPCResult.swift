import Foundation

public enum RpcResult: Codable, Equatable {
    enum Errors: Error {
        case decoding
    }

    case response(AnyCodable)
    case error(JSONRPCError)

    public var value: Codable {
        switch self {
        case .response(let value):
            return value
        case .error(let value):
            return value
        }
    }

    public init(from decoder: Decoder) throws {
        if let value = try? JSONRPCError(from: decoder) {
            self = .error(value)
        } else if let value = try? AnyCodable(from: decoder) {
            self = .response(value)
        } else {
            throw Errors.decoding
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .error(let value):
            try value.encode(to: encoder)
        case .response(let value):
            try value.encode(to: encoder)
        }
    }
}

public struct RpcParams: Codable {
    public let params: [Any]

    public init(params: [Any]) {
        self.params = params
    }

    public init(from decoder: Decoder) throws {
        params = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for par in params {
            if let p = par as? Codable {
                try container.encode(p)
            } else if let p = par as? String {
                try container.encode(p)
            } else if let p = par as? Bool {
                try container.encode(p)
            }
        }
    }
}
