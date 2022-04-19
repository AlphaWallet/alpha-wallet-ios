
import Foundation


public enum JsonRpcResult: Codable {
    case error(JSONRPCErrorResponse)
    case response(JSONRPCResponse<AnyCodable>)
    public var id: Int64 {
        switch self {
        case .error(let value):
            return value.id
        case .response(let value):
            return value.id
        }
    }
    public var value: Codable {
        switch self {
        case .error(let value):
            return value
        case .response(let value):
            return value
        }
    }
}
