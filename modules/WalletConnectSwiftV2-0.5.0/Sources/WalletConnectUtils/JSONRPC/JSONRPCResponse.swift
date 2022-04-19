
import Foundation

public struct JSONRPCResponse<T: Codable&Equatable>: Codable, Equatable {
    public let jsonrpc = "2.0"
    public let id: Int64
    public let result: T

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case result
    }

    public init(id: Int64, result: T) {
        self.id = id
        self.result = result
    }
}
