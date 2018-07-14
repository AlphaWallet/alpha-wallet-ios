//
// Created by James Sangalli on 14/7/18.
//

import Foundation
import TrustKeystore

struct GetIsERC721: Web3Request {
    typealias Response = String

    //Note: if this returns without error than it is ERC721 as non ERC721 contracts will not have this function
    static let abi = "{\"constant\":true,\"inputs\":[],\"name\":\"erc721Metadata\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"

    var type: Web3RequestType {
        let run = "web3.eth.abi.encodeFunctionCall(\(GetIsERC721.abi), [])"
        return .script(command: run)
    }
}

struct GetIsERC721Decode: Web3Request {
    typealias Response = String

    let data: String

    var type: Web3RequestType {
        let run = "web3.eth.abi.decodeParameter('address', '\(data)')"
        return .script(command: run)
    }
}