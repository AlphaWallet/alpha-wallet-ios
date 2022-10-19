// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3

public class GetContractDecimals {
    private let server: RPCServer

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getDecimals(for contract: AlphaWallet.Address) -> Promise<Int> {
        let functionName = "decimals"
        return callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: Web3.Utils.erc20ABI).map { dictionary -> Int in
            guard let decimalsOfUnknownType = dictionary["0"], let decimals = Int(String(describing: decimalsOfUnknownType)) else {
                throw CastError(actualValue: dictionary["0"], expectedType: Int.self)
            }

            return decimals
        }
    }
}
