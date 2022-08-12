// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift
import PromiseKit

class GetContractName {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getName(for contract: AlphaWallet.Address) -> Promise<String> {
        let functionName = "name"
        return callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI).map { nameResult -> String in
            if let name = nameResult["0"] as? String {
                return name
            } else {
                throw createSmartContractCallError(forContract: contract, functionName: functionName)
            }
        }
    }
}
