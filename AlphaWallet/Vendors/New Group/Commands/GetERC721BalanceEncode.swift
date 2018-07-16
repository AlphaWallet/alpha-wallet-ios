//
// Created by James Sangalli on 14/7/18.
//

import Foundation
import TrustKeystore

struct GetERC721BalanceEncode: Web3Request {
    typealias Response = String

    static let abi = "{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"tokensOfOwner\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"

    let address: Address

    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(GetERC721BalanceEncode.abi), [\"\(address.description)\"])"
        return .script(command: run)
    }
}

struct GetERC721BalanceDecode: Web3Request {
    typealias Response = String

    let data: String

    var type: Web3RequestType {
        let run = "web3.eth.abi.decodeParameter('uint256[]', '\(data)')"
        return .script(command: run)
    }
}