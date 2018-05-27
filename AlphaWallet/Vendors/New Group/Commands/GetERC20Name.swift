// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct GetERC20NameEncode: Web3Request {
    typealias Response = String
    
    static let abi = "{\"constant\":true,\"inputs\":[],\"name\":\"name\",\"outputs\":[{\"name\":\"name\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"
    
    
    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(GetERC20NameEncode.abi), [])"
        return .script(command: run)
    }
}

struct GetERC20NameDecode: Web3Request {
    typealias Response = String
    
    let data: String
    
    var type: Web3RequestType {
        let run = "web3.eth.abi.decodeParameter('string', '\(data)')"
        return .script(command: run)
    }
}

