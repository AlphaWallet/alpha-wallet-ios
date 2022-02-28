// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Result
import web3swift
import PromiseKit

class GetERC20BalanceCoordinator {
    private let server: RPCServer
    private let queue: DispatchQueue?

    init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    func getBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<BigInt> {
        let functionName = "balanceOf"
        return callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI, parameters: [address.eip55String] as [AnyObject], timeout: Constants.fetchContractDataTimeout).map(on: queue, { balanceResult in
            if let balanceWithUnknownType = balanceResult["0"] {
                let string = String(describing: balanceWithUnknownType)
                if let balance = BigInt(string) {
                    return balance
                } else {
                    throw AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))
                }
            } else {
                throw AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))
            }
        })
    }
}
