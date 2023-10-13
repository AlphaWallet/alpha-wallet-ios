// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore

//This is EIP-5169 https://github.com/ethereum/EIPs/pull/5169 , but the return type is `string`. A newer version of it returns `string[]`
fileprivate struct GetScriptUriReturningString {
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

public struct ScriptUriMethodCall: ContractMethodCall {
    public typealias Response = URL

    private let function = GetScriptUriReturningString()

    public let contract: AlphaWallet.Address
    public var name: String { function.name }
    public var abi: String { function.abi }

    public init(contract: AlphaWallet.Address) {
        self.contract = contract
    }

    public func response(from dictionary: [String: Any]) throws -> URL {
        guard let urlString = dictionary["0"] as? String, let url = URL(string: urlString) else {
            throw CastError(actualValue: dictionary["0"], expectedType: String.self)
        }
        return url.rewrittenIfIpfs
    }
}
