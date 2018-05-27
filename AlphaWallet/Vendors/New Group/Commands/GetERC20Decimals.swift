// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct GetERC20DecimalsEncode: Web3Request {
    typealias Response = String

    static let abi = "{\"constant\":true,\"inputs\":[],\"name\":\"decimals\",\"outputs\":[{\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"

    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(GetERC20DecimalsEncode.abi), [])"
        return .script(command: run)
    }
}

struct GetERC20DecimalsDecode: Web3Request {
    typealias Response = String

    let data: String

    var type: Web3RequestType {
        let run = "web3.eth.abi.decodeParameter('uint8', '\(data)')"
        return .script(command: run)
    }
}
