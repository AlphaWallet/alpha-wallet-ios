
import Foundation
import WalletConnectUtils

public struct Response: Codable {
    public let topic: String
    public let chainId: String?
    public let result: JsonRpcResult
}
