
import Foundation

public struct JSONRPCErrorResponse: Error, Equatable, Codable {
    public let jsonrpc = "2.0"
    public let id: Int64
    public let error: JSONRPCErrorResponse.Error

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case error
    }

    public init(id: Int64, error: JSONRPCErrorResponse.Error) {
        self.id = id
        self.error = error
    }
    
    public struct Error: Codable, Equatable {
        public let code: Int
        public let message: String
        public init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }
}
