// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

public class GetErc20Balance {
    private let server: RPCServer
    private let queue: DispatchQueue?

    public init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    public func getBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<BigInt> {
        let functionName = "balanceOf"
        return callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: Web3.Utils.erc20ABI, parameters: [address.eip55String] as [AnyObject], queue: queue)
            .map(on: queue, { balanceResult in
                guard let balanceOfUnknownType = balanceResult["0"], let balance = BigInt(String(describing: balanceOfUnknownType)) else {
                    throw CastError(actualValue: balanceResult["0"], expectedType: BigInt.self)
                }
                return balance
            })
    }
}
