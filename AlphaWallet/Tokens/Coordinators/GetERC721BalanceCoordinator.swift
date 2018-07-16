//
// Created by James Sangalli on 14/7/18.
//

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore
import JavaScriptKit
import BigInt

class GetERC721BalanceCoordinator {
    private let web3: Web3Swift
    init(
            web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getERC721TokenBalance(
            for address: Address,
            contract: Address,
            completion: @escaping (Result<[BigUInt], AnyError>) -> Void
    ) {
        let request = GetERC721BalanceEncode(address: address)
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                        batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let balance):
                        let request = GetERC721BalanceDecode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                let values: [BigUInt] = (self?.adapt(res))!
                                NSLog("result \(values)")
                                completion(.success(values))
                            case .failure(let error):
                                let err = error.error
                                if err is JSErrorDomain { // TODO:
                                    switch err {
                                    case JSErrorDomain.invalidReturnType(let value):
                                        let values: [BigUInt] = (self?.adapt(value))!
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

extension GetERC721BalanceCoordinator {
    private func adapt(_ values: Any) -> [BigUInt] {
        if let array = values as? [Any] {
            return array.map {
                if let val = BigUInt(String(describing: $0), radix: 16) {
                    return val
                }
                return BigUInt(0)
            }
        }
        return []
    }
}
