
import Foundation

public struct JsonRpcRecord: Codable {
    public let id: Int64
    public let topic: String
    public let request: Request
    public var response: JsonRpcResult?
    public let chainId: String?
    
    public init(id: Int64, topic: String, request: JsonRpcRecord.Request, response: JsonRpcResult? = nil, chainId: String?) {
        self.id = id
        self.topic = topic
        self.request = request
        self.response = response
        self.chainId = chainId
    }
    
    public struct Request: Codable {
        public let method: String
        public let params: AnyCodable
        
        public init(method: String, params: AnyCodable) {
            self.method = method
            self.params = params
        }
    }
}

