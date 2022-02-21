// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift
import PromiseKit

class GetSymbolCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getSymbol(for contract: AlphaWallet.Address) -> Promise<String> {
        let functionName = "symbol"
        return callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI, timeout: Constants.fetchContractDataTimeout).map { symbolsResult -> String in
            if let symbol = symbolsResult["0"] as? String {
                return symbol
            } else {
                throw AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))
            }
        }
    }
}
