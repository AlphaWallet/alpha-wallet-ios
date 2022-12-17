// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

extension RpcRequest {
    static func gasPrice() -> RpcRequest {
        RpcRequest(method: "eth_gasPrice")
    }
}
