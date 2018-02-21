// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class GetDecimalsCoordinator {

    private let web3: Web3Swift

    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getDecimals(
        for contract: Address,
        completion: @escaping (Result<UInt8, AnyError>) -> Void
    ) {
        let request = GetERC20DecimalsEncode()
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let balance):
                        let request = GetERC20DecimalsDecode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                NSLog("result is \(res)")
                                completion(.success(UInt8(res) ?? UInt8()))
                            case .failure(let error):
                                NSLog("getDecimals3 error \(error)")
                                completion(.failure(AnyError(error)))
                            }
                        }
                    case .failure(let error):
                        NSLog("getDecimals2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getDecimals error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}
