// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift
import PromiseKit

class ScriptUri {
    private let server: RPCServer
    private let abiString = """
                            [
                                {
                                  "constant" : false,
                                  "inputs" : [
                                  ],
                                  "name" : "scriptURI",
                                  "outputs" : [
                                    {
                                      "name" : "",
                                      "type" : "string"
                                    }
                                  ],
                                  "payable" : false,
                                  "stateMutability" : "nonpayable",
                                  "type" : "function"
                                }
                            ]
                            """

    init(forServer server: RPCServer) {
        self.server = server
    }

    func get(forContract contract: AlphaWallet.Address) -> Promise<URL> {
        let functionName = "scriptURI"
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: abiString)
        }.map { urlStringResult in
            if let urlString = urlStringResult["0"] as? String {
                if let url = URL(string: urlString) {
                    let url = url.rewrittenIfIpfs
                    return url
                } else {
                    throw AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))
                }
            } else {
                throw AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))
            }
        }
    }
}
