// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift

class GetDecimalsCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getDecimals(
        for contract: AlphaWallet.Address,
        completion: @escaping (Result<UInt8, AnyError>) -> Void
    ) {
        let functionName = "decimals"
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI).done { dictionary in
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
