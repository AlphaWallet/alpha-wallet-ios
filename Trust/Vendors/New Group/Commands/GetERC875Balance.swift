// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct GetERC875BalanceEncode: Web3Request {
    typealias Response = String

    static let abi = "{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"\",\"type\":\"uint16[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"

    let address: Address

    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(GetERC875BalanceEncode.abi), [\"\(address.description)\"])"
        return .script(command: run)
    }
}

struct GetERC875BalanceDecode: Web3Request {
    typealias Response = String

    let data: String

    var type: Web3RequestType {
        let run = "web3.eth.abi.decodeParameter('uint16[4]', '\(data)')"
        return .script(command: run)
    }
}
