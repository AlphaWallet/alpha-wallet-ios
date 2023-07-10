//
//  Erc721ScriptUriMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

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

public struct Erc721ScriptUriMethodCall: ContractMethodCall {
    public typealias Response = URL

    private let function = GetScriptUri()

    public let contract: AlphaWallet.Address
    public var name: String { function.name }
    public var abi: String { function.abi }

    public init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> URL {
        guard let urlString = dictionary["0"] as? String, let url = URL(string: urlString) else {
            throw CastError(actualValue: dictionary["0"], expectedType: URL.self)
        }

        return url.rewrittenIfIpfs
    }
}
