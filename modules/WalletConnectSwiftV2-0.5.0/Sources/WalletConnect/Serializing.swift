
import Foundation
import WalletConnectKMS

public protocol Serializing {
    func serialize(topic: String, encodable: Encodable) throws -> String
    func tryDeserialize<T: Codable>(topic: String, message: String) -> T?
}

extension Serializer: Serializing {}
