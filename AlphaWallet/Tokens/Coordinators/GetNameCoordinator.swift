// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import TrustKeystore
import web3swift

class GetNameCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func getName(
        for contract: Address,
        completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        let functionName = "name"
        callSmartContract(withConfig: config, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI).done { nameResult in
            if let name = nameResult["0"] as? String {
                completion(.success(name))
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
}
