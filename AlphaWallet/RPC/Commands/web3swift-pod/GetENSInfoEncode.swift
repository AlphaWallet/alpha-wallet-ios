//
// Created by James Sangalli on 8/11/18.
//

import Foundation

struct GetENSResolverEncode {
    let abi = "[ { \"constant\": false, \"inputs\": [ { \"name\": \"node\", \"type\": \"bytes32\" } ], \"name\": \"resolver\", \"outputs\": [ { \"name\": \"\", \"type\": \"address\" } ], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" } ]"
    let name = "resolver"
}

struct GetENSRecordWithResolverAddrEncode {
    let abi = "[ { \"constant\": false, \"inputs\": [ { \"name\": \"node\", \"type\": \"bytes32\" } ], \"name\": \"addr\", \"outputs\": [ { \"name\": \"\", \"type\": \"address\" } ], \"payable\": false, \"stateMutability\": \"nonpayable\", \"type\": \"function\" } ]"
    let name = "addr"
}

struct GetENSRecordWithResolverResolveEncode {
    let abi = """
              [ { "constant" : false, "inputs" : [ { "name" : "name", "type" : "bytes" }, { "name" : "data", "type" : "bytes" } ], "name" : "resolve", "outputs" : [ { "name" : "", "type" : "bytes" } ], "payable" : false, "stateMutability" : "nonpayable", "type" : "function" } ]
              """
    let name = "resolve"
}

struct GetENSTextRecord {
    let abi = "[{\"constant\":true,\"inputs\":[{\"name\":\"node\",\"type\":\"bytes32\"},{\"name\":\"key\",\"type\":\"string\"}],\"name\":\"text\",\"outputs\":[{\"name\":\"ret\",\"type\":\"string\"}],\"payable\":false,\"type\":\"function\"}]"
    let name = "text"
}

struct GetENSNameRecord {
    let abi = "[{\"constant\":true,\"inputs\":[{\"name\":\"node\",\"type\":\"bytes32\"}],\"name\":\"name\",\"outputs\":[{\"name\":\"ret\",\"type\":\"string\"}],\"payable\":false,\"type\":\"function\"}]"
    let name = "name"
}
