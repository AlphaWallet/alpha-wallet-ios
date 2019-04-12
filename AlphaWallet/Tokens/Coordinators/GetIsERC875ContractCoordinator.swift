// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import TrustKeystore

class GetIsERC875ContractCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC875Contract(
        for contract: Address,
        completion: @escaping (Result<Bool, AnyError>) -> Void
    ) {
        let function = GetIsERC875()
        callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi).done { dictionary in
            if let isERC875 = dictionary["0"] as? Bool {
                completion(.success(isERC875))
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)()"))))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
}
