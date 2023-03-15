//
//  Erc721ScriptUriMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation

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

struct Erc721ScriptUriMethodCall: ContractMethodCall {
    typealias Response = URL

    private let function = GetScriptUri()

    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }

    init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    func response(from dictionary: [String: Any]) throws -> URL {
        guard let urlString = dictionary["0"] as? String, let url = URL(string: urlString) else {
            throw CastError(actualValue: dictionary["0"], expectedType: URL.self)
        }

        return url.rewrittenIfIpfs
    }
}
