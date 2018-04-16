// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct GetStormBirdBalanceEncode: Web3Request {
    typealias Response = String

    static let abi = "{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"\",\"type\":\"bytes32[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"

    let address: Address

    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(GetStormBirdBalanceEncode.abi), [\"\(address.description)\"])"
        return .script(command: run)
    }
}

struct GetStormBirdBalanceDecode: Web3Request {
    typealias Response = String

    let data: String

    var type: Web3RequestType {
        let run = "web3.eth.abi.decodeParameter('bytes32[]', '\(data)')"
        return .script(command: run)
    }
}
