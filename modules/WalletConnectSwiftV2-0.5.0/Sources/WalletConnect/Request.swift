import Foundation
import WalletConnectUtils

public struct Request: Codable, Equatable {
    public let id: Int64
    public let topic: String
    public let method: String
    public let params: AnyCodable
    public let chainId: String?
    
    internal init(id: Int64, topic: String, method: String, params: AnyCodable, chainId: String?) {
        self.id = id
        self.topic = topic
        self.method = method
        self.params = params
        self.chainId = chainId
    }
    
    public init(topic: String, method: String, params: AnyCodable, chainId: String?) {
        self.id = Self.generateId()
        self.topic = topic
        self.method = method
        self.params = params
        self.chainId = chainId
    }
    
    public static func generateId() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)*1000 + Int64.random(in: 0..<1000)
    }
}
