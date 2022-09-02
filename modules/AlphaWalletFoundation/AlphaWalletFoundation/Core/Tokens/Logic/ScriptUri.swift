// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import web3swift
import PromiseKit

public class ScriptUri {
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

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func get(forContract contract: AlphaWallet.Address) -> Promise<URL> {
        let functionName = "scriptURI"
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: abiString)
        }.map { urlStringResult in
            if let urlString = urlStringResult["0"] as? String {
                if let url = URL(string: urlString) {
                    let url = url.rewrittenIfIpfs
                    return url
                } else {
                    throw createSmartContractCallError(forContract: contract, functionName: functionName)
                }
            } else {
                throw createSmartContractCallError(forContract: contract, functionName: functionName)
            }
        }
    }
}
