// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import PromiseKit

class GetERC875BalanceCoordinator {
    private let queue: DispatchQueue?
    private let server: RPCServer

    init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    func getERC875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        let function = GetERC875Balance()
        return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject], timeout: Constants.fetchContractDataTimeout).map(on: queue, { balanceResult -> [String] in
            return GetERC875BalanceCoordinator.adapt(balanceResult["0"])
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
