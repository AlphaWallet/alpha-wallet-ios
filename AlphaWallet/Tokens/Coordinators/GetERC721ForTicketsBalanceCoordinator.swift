// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Result
import BigInt

class GetERC721ForTicketsBalanceCoordinator: CallbackQueueProvider {
    var queue: DispatchQueue?

    private let server: RPCServer

    init(forServer server: RPCServer, queue: DispatchQueue? = nil) {
        self.server = server
        self.queue = queue
    }

    func getERC721ForTicketsTokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address, completion: @escaping (Result<[String], AnyError>) -> Void) {
        let function = GetERC721ForTicketsBalance()
        callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [address.eip55String] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout).done(on: queue, { balanceResult in
            let balances = self.adapt(balanceResult["0"])
            completion(.success(balances))
        }).catch(on: queue, {
            completion(.failure(AnyError($0)))
        })
    }

    private func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [BigUInt] else { return [] }
        return array.filter({ $0 != BigUInt(0) }).map { each in
            let value = each.serialize().hex()
            return "0x\(value)"
        }
    }
}
