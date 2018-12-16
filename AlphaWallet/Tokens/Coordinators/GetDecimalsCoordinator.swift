// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import TrustKeystore
import web3swift

class GetDecimalsCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func getDecimals(
        for contract: Address,
        completion: @escaping (Result<UInt8, AnyError>) -> Void
    ) {
        let functionName = "decimals"
        callSmartContract(withConfig: config, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI).done { dictionary in
            if let decimalsWithUnknownType = dictionary["0"] {
                let string = String(describing: decimalsWithUnknownType)
                if let decimals = UInt8(string) {
                    completion(.success(decimals))
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
                }
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
}
