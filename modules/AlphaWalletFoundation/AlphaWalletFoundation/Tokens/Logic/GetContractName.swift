// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3

public class GetContractName {
    private let server: RPCServer

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getName(for contract: AlphaWallet.Address) -> Promise<String> {
        let functionName = "name"
        return callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: Web3.Utils.erc20ABI).map { nameResult -> String in
            guard let name = nameResult["0"] as? String else {
                throw CastError(actualValue: nameResult["0"], expectedType: String.self)
            }
            return name
        }
    }
}
