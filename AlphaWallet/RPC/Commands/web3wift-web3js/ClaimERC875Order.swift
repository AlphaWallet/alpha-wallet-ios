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

struct ClaimERC875OrderEncode {
    func getAbi(contractAddress: String) -> String {
        if contractAddress.isLegacy875Contract {
            return "[{\"constant\":false,\"inputs\":[{\"name\":\"expiry\",\"type\":\"uint256\"},{\"name\":\"indices\",\"type\":\"uint16[]\"},{\"name\":\"v\",\"type\":\"uint8\"},{\"name\":\"r\",\"type\":\"bytes32\"},{\"name\":\"s\",\"type\":\"bytes32\"}],\"name\":\"trade\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"}]"
        } else {
            return "[{\"constant\":false,\"inputs\":[{\"name\":\"expiry\",\"type\":\"uint256\"},{\"name\":\"indices\",\"type\":\"uint256[]\"},{\"name\":\"v\",\"type\":\"uint8\"},{\"name\":\"r\",\"type\":\"bytes32\"},{\"name\":\"s\",\"type\":\"bytes32\"}],\"name\":\"trade\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"}]"
        }
    }
    let name = "trade"
}

struct ClaimERC875SpawnableEncode {
    let abi = "[{ \"constant\": false, \"inputs\": [ { \"name\": \"expiry\", \"type\": \"uint256\" }, { \"name\": \"tickets\", \"type\": \"uint256[]\" }, { \"name\": \"v\", \"type\": \"uint8\" }, { \"name\": \"r\", \"type\": \"bytes32\" }, { \"name\": \"s\", \"type\": \"bytes32\" }, { \"name\": \"recipient\", \"type\": \"address\" } ], \"name\": \"spawnPassTo\", \"outputs\": [], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" }]"
    let name = "spawnablePassTo"
}
