// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import PromiseKit

//EIP-5169 https://github.com/ethereum/EIPs/pull/5169
public class ScriptUri {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func get(forContract contract: AlphaWallet.Address) -> Promise<URL> {
        blockchainProvider.callPromise(Erc721ScriptUriRequest(contract: contract))
    }
}

struct GetScriptUri {
    let abi = """
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
    let name = "scriptURI"
    
}

struct Erc721ScriptUriRequest: ContractMethodCall {
    typealias Response = URL

    private let function = GetScriptUri()

    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from resultObject: Any) throws -> URL {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let urlString = dictionary["0"] as? String, let url = URL(string: urlString) else {
            throw CastError(actualValue: dictionary["0"], expectedType: URL.self)
        }

        return url.rewrittenIfIpfs
    }
}
