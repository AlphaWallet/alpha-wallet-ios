// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct GetIsStormBirdEncode: Web3Request {
    typealias Response = String
    
    static let abi = "{\"constant\":true,\"inputs\":[],\"name\":\"isStormBirdContract\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"

    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(GetIsStormBirdEncode.abi), [])"
        return .script(command: run)
    }
}

struct GetIsStormBirdDecode: Web3Request {
    typealias Response = String
    
    let data: String
    
    var type: Web3RequestType {
        let run = "web3.eth.abi.decodeParameter('uint256', '\(data)')"
        return .script(command: run)
    }
}

