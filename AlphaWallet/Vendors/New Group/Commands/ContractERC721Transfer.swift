//
// Created by James Sangalli on 14/7/18.
//

import Foundation
import BigInt

struct ContractERC721Transfer: Web3Request {

    //function transfer(address _to, uint256 _tokenId) external; - TODO cannot transfer by bulk, should group one by one
    typealias Response = String
    let address: String
    let tokenId: BigUInt

    var type: Web3RequestType {
        let abi = "{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_tokenId\",\"type\":\"uint256\"}],\"name\":\"transfer\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"}, [\"\(address)\", \(tokenId)]"
        let run = "web3.eth.abi.encodeFunctionCall(" + abi + ")"
        return .script(command: run)
    }
}
