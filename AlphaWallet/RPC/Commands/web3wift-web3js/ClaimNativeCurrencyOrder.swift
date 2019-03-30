//
// Created by James Sangalli on 26/1/19.
//

import Foundation
import BigInt

struct ClaimNativeCurrencyOrder {
    let abi = "{ \"constant\": false, \"inputs\": [{ \"name\": \"nonce\", \"type\": \"uint32\" }, { \"name\": \"amount\", \"type\": \"uint32\" }, { \"name\": \"expiry\", \"type\": \"uint32\" }, { \"name\": \"v\", \"type\": \"uint8\" }, { \"name\": \"r\", \"type\": \"bytes32\" }, { \"name\": \"s\", \"type\": \"bytes32\" }, { \"name\": \"receiver\", \"type\": \"address\" } ], \"name\": \"dropCurrency\", \"outputs\": [], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" }"
    let name = "dropCurrency"
}
