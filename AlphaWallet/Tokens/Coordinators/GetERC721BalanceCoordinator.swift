//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import PromiseKit
import Result

class GetERC721BalanceCoordinator {
    private let queue: DispatchQueue?
    private let server: RPCServer

    init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    func getERC721TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<BigUInt> {
        let function = GetERC721Balance()
        return callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject], timeout: Constants.fetchContractDataTimeout).map(on: queue, { balanceResult -> BigUInt in
            let balance = GetERC721BalanceCoordinator.adapt(balanceResult["0"] as Any)
            return balance
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
