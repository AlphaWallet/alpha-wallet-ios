// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore
import JavaScriptKit

class GetStormBirdBalanceCoordinator {

    private let web3: Web3Swift

    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getBalance(
        for address: Address,
        contract: Address,
        completion: @escaping (Result<[UInt16], AnyError>) -> Void
    ) {
        let request = GetStormBirdBalanceEncode(address: address)
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let balance):
                        let request = GetStormBirdBalanceDecode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                let values:[UInt16] = (self?.adapt(res))!
                                NSLog("result \(values)")
                                completion(.success(values))
                            case .failure(let error):
                                let err = error.error
                                if err is JSErrorDomain { // TODO:
                                    switch err {
                                    case JSErrorDomain.invalidReturnType(let value):
                                        let values:[UInt16] = (self?.adapt(value))!
                                        NSLog("result error \(values)")
                                        completion(.success(values))
                                    default:
                                         completion(.failure(AnyError(error)))
                                    }
                                } else {
                                    NSLog("getPrice3 error \(error)")
                                    completion(.failure(AnyError(error)))
                                }
                            }
                        }
                    case .failure(let error):
                        NSLog("getPrice2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getPrice error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}

extension GetStormBirdBalanceCoordinator {
    private func adapt(_ values: Any) -> [UInt16] {
        if let array = values as? [Any] {
            return array.map { UInt16($0 as! String)! }
        }
        return []
    }
}
