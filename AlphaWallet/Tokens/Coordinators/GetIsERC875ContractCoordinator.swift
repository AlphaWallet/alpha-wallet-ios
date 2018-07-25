// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class GetIsERC875ContractCoordinator {

    private let web3: Web3Swift

    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getIsERC875Contract(
        for contract: Address,
        completion: @escaping (Result<Bool, AnyError>) -> Void
    ) {
        let request = GetIsERC875Encode()
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let is875):
                        let request = GetIsERC875Decode(data: is875)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                let isERC875 = res.toBool()
                                NSLog("getIsERC875Contract result \(isERC875) ")
                                completion(.success(isERC875))
                            case .failure(let error):
                                NSLog("getIsERC875Contract 3 error \(error)")
                                completion(.failure(AnyError(error)))
                            }
                        }
                    case .failure(let error):
                        NSLog("getIsERC875Contract 2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getIsERC875Contract error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}
