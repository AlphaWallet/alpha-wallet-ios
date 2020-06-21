// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift

class GetSymbolCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getSymbol(
        for contract: AlphaWallet.Address,
        completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        let functionName = "symbol"
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI, timeout: TokensDataStore.fetchContractDataTimeout).done { symbolsResult in
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
