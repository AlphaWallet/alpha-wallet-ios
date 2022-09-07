// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit

public class GetErc875Balance {
    private let queue: DispatchQueue?
    private let server: RPCServer

    public init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    public func getERC875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        let function = GetERC875Balance()
        return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject]).map(on: queue, { balanceResult -> [String] in
            return GetErc875Balance.adapt(balanceResult["0"])
        })
    }

    private static func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [Data] else { return [] }
        return array.map { each in
            let value = each.toHexString()
            return "0x\(value)"
        }
    }
}
