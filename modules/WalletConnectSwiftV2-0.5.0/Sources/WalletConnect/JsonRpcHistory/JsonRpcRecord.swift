

import Foundation
import WalletConnectUtils

struct JsonRpcRecord: Codable {
    let id: Int64
    let topic: String
    let request: Request
    var response: JsonRpcResult?
    let chainId: String?

    struct Request: Codable {
        let method: WCRequest.Method
        let params: WCRequest.Params
    }
}

