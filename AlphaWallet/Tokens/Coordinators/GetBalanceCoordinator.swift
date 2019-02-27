// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore
import web3swift

class GetBalanceCoordinator {
    let server: RPCServer

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getBalance(
        for address: Address,
        contract: Address,
        completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void
    ) {
        let functionName = "balanceOf"
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: web3swift.Web3.Utils.erc20ABI, parameters: [address.eip55String] as [AnyObject]).done { balanceResult in
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

    func getEthBalance(
        for address: Address,
        completion: @escaping (ResultResult<Balance, AnyError>.t) -> Void
    ) {
        let request = EtherServiceRequest(server: server, batch: BatchFactory().create(BalanceRequest(address: address.description)))
        Session.send(request) { result in
            switch result {
            case .success(let balance):
                completion(.success(balance))
            case .failure(let error):
                completion(.failure(AnyError(error)))
            }
        }
    }
}

