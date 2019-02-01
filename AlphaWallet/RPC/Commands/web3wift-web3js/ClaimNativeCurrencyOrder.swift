//
// Created by James Sangalli on 26/1/19.
//

import Foundation
import BigInt

struct ClaimNativeCurrencyOrder: Web3Request {

    typealias Response = String
    let contractAddress: String
    let nonce: BigUInt
    let expiry: BigUInt
    let amount: BigUInt //in szabo
    let v: UInt8
    let r: String
    let s: String
    let receiver: String

    var type: Web3RequestType {
        let abi = "{ \"constant\": false, \"inputs\": [{ \"name\": \"nonce\", \"type\": \"uint32\" }, { \"name\": \"amount\", \"type\": \"uint32\" }, { \"name\": \"expiry\", \"type\": \"uint32\" }, { \"name\": \"v\", \"type\": \"uint8\" }, { \"name\": \"r\", \"type\": \"bytes32\" }, { \"name\": \"s\", \"type\": \"bytes32\" }, { \"name\": \"receiver\", \"type\": \"address\" } ], \"name\": \"dropCurrency\", \"outputs\": [], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" }, [\"\(nonce)\", \"\(amount)\", \"\(expiry)\", \"\(v)\", \"\(r)\", \"\(s)\", \"\(receiver)\" ]"
        let run = "web3.eth.abi.encodeFunctionCall(" + abi + ")"
        return .script(command: run)
    }

}
