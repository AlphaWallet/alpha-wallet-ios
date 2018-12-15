// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import TrustKeystore
import web3swift

class GetSymbolCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func getSymbol(
        for contract: Address,
        completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        let functionName = "symbol"
        callSmartContract(withConfig: config, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI).done { symbolsResult in
            if let symbol = symbolsResult["0"] as? String {
                completion(.success(symbol))
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }
}
