// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class GetNameCoordinator {

    private let web3: Web3Swift

    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getName(
        for contract: Address,
        completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        let request = GetERC20NameEncode()
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let balance):
                        let request = GetERC20NameDecode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                completion(.success(res))
                            case .failure(let error):
                                NSLog("getName3 error \(error)")
                                completion(.failure(AnyError(error)))
                            }
                        }
                    case .failure(let error):
                        NSLog("getName2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getName error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}
