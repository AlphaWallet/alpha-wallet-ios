//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import PromiseKit

public class GetErc721Balance {
    private let queue: DispatchQueue?
    private let server: RPCServer

    public init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    public func getERC721TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        let function = GetERC721Balance()
        return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject], queue: queue)
            .map(on: queue, { balanceResult -> BigUInt in
                let balance = GetErc721Balance.adapt(balanceResult["0"] as Any)
                return balance
            }).map(on: queue, { balance -> [String] in
                if balance >= Int.max {
                    throw Web3Error(description: "")
                } else {
                    return [String](repeating: "0", count: Int(balance))
                }
            })
    }

    private static func adapt(_ value: Any) -> BigUInt {
        if let value = value as? BigUInt {
            return value
        } else {
            return BigUInt(0)
        }
    }
}
