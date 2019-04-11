//
// Created by James Sangalli on 8/11/18.
//

import Foundation

struct GetENSResolverEncode {
    let abi = "[ { \"constant\": false, \"inputs\": [ { \"name\": \"node\", \"type\": \"bytes32\" } ], \"name\": \"resolver\", \"outputs\": [ { \"name\": \"\", \"type\": \"address\" } ], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" } ]"
    let name = "resolver"
}

struct GetENSRecordFromResolverEncode {
    let abi = "[ { \"constant\": false, \"inputs\": [ { \"name\": \"node\", \"type\": \"bytes32\" } ], \"name\": \"addr\", \"outputs\": [ { \"name\": \"\", \"type\": \"address\" } ], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" } ]"
    let name = "addr"
}
