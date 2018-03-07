//
// Created by James Sangalli on 7/3/18.
//

import Foundation
import Foundation
import TrustKeystore

struct ClaimStormBirdOrder: Web3Request {
    typealias Response = String

    static let abi = "{\"constant\":false,\"inputs\":[{\"name\":\"expiry\",\"type\":\"uint256\"},{\"name\":" +
            "\"ticketIndices\",\"type\":\"int16[]\"},{\"name\":\"v\",\"type\":\"uint8\"},{\"name\":\"r\",\"type\"" +
            ":\"bytes32\"},{\"name\":\"s\",\"type\":\"bytes32\"}],\"name\":\"trade\",\"outputs\":[]," +
            "\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"}"

    let address: Address

    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(ClaimStormBirdOrder.abi), [\"\(address.description)\"])"
        return .script(command: run)
    }
}

struct ClaimStormBirdOrderDecode: Web3Request {
    typealias Response = String

    let data: String

    var type: Web3RequestType {
        let run = ""
        return .script(command: run)
    }
}

