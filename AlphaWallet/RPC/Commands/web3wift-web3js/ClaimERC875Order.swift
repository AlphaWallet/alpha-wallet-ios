//
// Created by James Sangalli on 7/3/18.
// Copyright © 2018 Stormbird PTE. LTD.
//
// This is a struct with the capacity to convert an order to a new format:
// the data field of a transaction.
// There are 4 formats of orders:
// 1) the binary data the signature is corrisponding to.
// 2) the compressed format, which is Base64 encoded to UniversalLink
// 3) the JSON format, which is used to pass to feeMaster server.
// 4) this data format, to pass as part of an Ethereum transaction
// This class gets you the 4th format.
//

import Foundation
import Foundation
import TrustKeystore
import BigInt

struct ClaimERC875Order: Web3Request {
    typealias Response = String

    let expiry: BigUInt
    //we still use indices in the trade but interpret the tokens from their hex values
    //TODO switch to BigUInt
    let indices: [UInt16]
    let v: UInt8
    let r: String
    let s: String
    let contractAddress: String

    var type: Web3RequestType {
        var abi = ""
        if contractAddress.isLegacy875Contract {
            abi = "{\"constant\":false,\"inputs\":[{\"name\":\"expiry\",\"type\":\"uint256\"},{\"name\":\"indices\",\"type\":\"uint16[]\"},{\"name\":\"v\",\"type\":\"uint8\"},{\"name\":\"r\",\"type\":\"bytes32\"},{\"name\":\"s\",\"type\":\"bytes32\"}],\"name\":\"trade\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"}, [\"\(expiry)\", \(indices), \(v), \"\(r)\", \"\(s)\"]"
        } else {
            abi = "{\"constant\":false,\"inputs\":[{\"name\":\"expiry\",\"type\":\"uint256\"},{\"name\":\"indices\",\"type\":\"uint256[]\"},{\"name\":\"v\",\"type\":\"uint8\"},{\"name\":\"r\",\"type\":\"bytes32\"},{\"name\":\"s\",\"type\":\"bytes32\"}],\"name\":\"trade\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"}, [\"\(expiry)\", \(indices), \(v), \"\(r)\", \"\(s)\"]"
        }
        let run = "web3.eth.abi.encodeFunctionCall(" + abi + ")"
        return .script(command: run)
    }
}

struct ClaimERC875Spawnable: Web3Request {
    typealias Response = String
    let tokenIds: [BigUInt]
    let v: UInt8
    let r: String
    let s: String
    let expiry: BigUInt
    let recipient: String

    var type: Web3RequestType {
        //BigUInt is cast incorrectly, must be converted to hex string values
        let tokenStrings: [String] = tokenIds.map { token in String(token, radix: 16) }
        let abi = "{ \"constant\": false, \"inputs\": [ { \"name\": \"expiry\", \"type\": \"uint256\" }, { \"name\": \"tickets\", \"type\": \"uint256[]\" }, { \"name\": \"v\", \"type\": \"uint8\" }, { \"name\": \"r\", \"type\": \"bytes32\" }, { \"name\": \"s\", \"type\": \"bytes32\" }, { \"name\": \"recipient\", \"type\": \"address\" } ], \"name\": \"spawnPassTo\", \"outputs\": [], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" }, [\"\(expiry)\", \(tokenStrings), \(v), \"\(r)\", \"\(s)\", \"\(recipient)\"]"
        let run = "web3.eth.abi.encodeFunctionCall(" + abi + ")"
        return .script(command: run)
    }
}
