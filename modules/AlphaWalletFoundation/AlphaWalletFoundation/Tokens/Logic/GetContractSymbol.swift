// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public class GetContractSymbol {
    private let server: RPCServer

    public init(forServer server: RPCServer) {
        self.server = server
    }

    public func getSymbol(for contract: AlphaWallet.Address) -> Promise<String> {
        let functionName = "symbol"
        return callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: Web3.Utils.erc20ABI).map { symbolsResult -> String in
            guard let symbol = symbolsResult["0"] as? String else {
                throw CastError(actualValue: symbolsResult["0"], expectedType: String.self)
            }
            return symbol
        }
    }
}
