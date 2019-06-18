// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift

class GetNameCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getName(
        for contract: AlphaWallet.Address,
        completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        let functionName = "name"
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI).done { nameResult in
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
