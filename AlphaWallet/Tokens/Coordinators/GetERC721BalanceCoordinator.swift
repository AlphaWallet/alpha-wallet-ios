//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import Result
import TrustKeystore

class GetERC721BalanceCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getERC721TokenBalance(
            for address: Address,
            contract: Address,
            completion: @escaping (Result<BigUInt, AnyError>) -> Void
    ) {
        do {
            let function = GetERC721Balance()
            let encoder = ABIEncoder()
            try encoder.encode(signature: "balanceOf(address)")
            try encoder.encode(ABIValue(address.eip55String, type: ABIType.address))
            callSmartContract(
                    withServer: server,
                    contract: contract,
                    functionName: function.name,
                    abiString: function.abi,
                    data: encoder.data).done { balanceResult in
                let balance = self.adapt(balanceResult["0"])
                completion(.success(balance))
            }.catch { error in
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)(): \(error)"))))
            }
        } catch {

        }
    }

    private func adapt(_ value: Any) -> BigUInt {
        if let value = value as? BigUInt {
            return value
        } else {
            return BigUInt(0)
        }
    }
}
