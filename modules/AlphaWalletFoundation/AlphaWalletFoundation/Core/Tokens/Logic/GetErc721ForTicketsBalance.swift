// Copyright © 2019 Stormbird PTE. LTD.

import Foundation 
import BigInt
import PromiseKit

public class GetErc721ForTicketsBalance {
    private let queue: DispatchQueue?
    private let server: RPCServer

    public init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    public func getERC721ForTicketsTokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        let function = GetERC721ForTicketsBalance()
        return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject], queue: queue).map(on: queue, { balanceResult in
            return GetErc721ForTicketsBalance.adapt(balanceResult["0"])
        })
    }

    private static func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [BigUInt] else { return [] }
        return array.filter({ $0 != BigUInt(0) }).map { each in
            let value = each.serialize().hex()
            return "0x\(value)"
        }
    }
}
