// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension RpcRequest {
    static func sendRawTransaction(rawTransaction: String) -> RpcRequest {
        RpcRequest(method: "eth_sendRawTransaction", params: [rawTransaction])
    }
}
