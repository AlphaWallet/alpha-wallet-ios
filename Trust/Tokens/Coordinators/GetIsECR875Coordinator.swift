// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class GetIsECR875Coordinator {

    private let web3: Web3Swift

    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getIsECR875 (
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
                    case .success(let balance):
                        let request = GetIsERC875Decode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                let isECR875 = res.toBool()
                                NSLog("getIsECR875 result \(isECR875) ")
                                completion(.success(isECR875))
                            case .failure(let error):
                                NSLog("getIsECR875 3 error \(error)")
                                completion(.failure(AnyError(error)))
                            }
                        }
                    case .failure(let error):
                        NSLog("getIsECR875 2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getIsECR875 error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}
