// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class GetSymbolCoordinator {

    private let web3: Web3Swift

    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getSymbol(
        for contract: Address,
        completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        let request = GetERC20SymbolEncode()
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let balance):
                        let request = GetERC20SymbolDecode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                completion(.success(res))
                            case .failure(let error):
                                NSLog("getSymbol3 error \(error)")
                                completion(.failure(AnyError(error)))
                            }
                        }
                    case .failure(let error):
                        NSLog("getSymbol2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getSymbol error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}
