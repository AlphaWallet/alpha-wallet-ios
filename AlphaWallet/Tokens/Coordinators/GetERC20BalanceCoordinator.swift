// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Result
import web3swift

class GetERC20BalanceCoordinator {
    private let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getBalance(
            for address: AlphaWallet.Address,
            contract: AlphaWallet.Address,
            completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void
    ) {
        //TODO fix for activities: we want to show the correct balance for the debt token
        if contract.sameContract(as: Constants.Contracts.aaveDebt) {
            let abi = "[{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"},{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"getCurrentBorrowBalance\",\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},]"
            let functionName = "getCurrentBorrowBalance"
            callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: abi, parameters: ["0x6B175474E89094C44Da98b954EedeAC495271d0F", address.eip55String] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout).done { balanceResult in
                if let balanceWithUnknownType = balanceResult["0"] {
                    let string = String(describing: balanceWithUnknownType)
                    if let balance = BigInt(string) {
                        completion(.success(balance))
                    } else {
                        completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
                    }
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()"))))
                }
            }.catch {
                completion(.failure(AnyError($0)))
            }
            return
        }

        let functionName = "balanceOf"
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI, parameters: [address.eip55String] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout).done { balanceResult in
            if let balanceWithUnknownType = balanceResult["0"] {
                let string = String(describing: balanceWithUnknownType)
                if let balance = BigInt(string) {
                    completion(.success(balance))
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
