// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import PromiseKit

//EIP-5169 https://github.com/ethereum/EIPs/pull/5169
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
            guard let urlString = urlStringResult["0"] as? String, let url = URL(string: urlString) else {
                throw CastError(actualValue: urlStringResult["0"], expectedType: URL.self)
            }
            return url.rewrittenIfIpfs
        }
    }
}
