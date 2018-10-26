// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct ContractERC875Transfer: Web3Request {

    typealias Response = String
    let address: String
    let contractAddress: String
    //todo: should go to BigUInts in future
    let indices: [UInt16]

    var type: Web3RequestType {
        var abi = ""
        if contractAddress.isLegacy875Contract {
            abi = "{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"indices\",\"type\":\"uint16[]\"}],\"name\":\"transfer\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"}, [\"\(address)\", \(indices)]"
        } else {
            abi = "{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"indices\",\"type\":\"uint256[]\"}],\"name\":\"transfer\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"}, [\"\(address)\", \(indices)]"
        }
        let run = "web3.eth.abi.encodeFunctionCall(" + abi + ")"
        return .script(command: run)
    }

}
