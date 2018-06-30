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
    //TODO remove
    var tag = ""
    //TODO remove
    deinit {
        if tag == "foo" {
            NSLog("xxx deinit balance coordinator")
        }
    }

    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getStormBirdBalance(
        for address: Address,
        contract: Address,
        completion: @escaping (Result<[String], AnyError>) -> Void
    ) {
        let request = GetStormBirdBalanceEncode(address: address)
        //TODO remove
        let tag2 = tag
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                //TODO remove
                if tag2 == "foo" {
                    NSLog("xxx back in balance coordinator")
                }
                //TODO immediately after this next Session.send() call, this instance of GetStormBirdBalanceEncode will be destroyed if we don't store a strong reference to it because the block passed on Session.send() does not hold a strong reference to self (because of the weak self)
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let balance):
                        let request = GetStormBirdBalanceDecode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                let values: [String] = (self?.adapt(res))!
                                NSLog("result \(values)")
                                completion(.success(values))
                            case .failure(let error):
                                let err = error.error
                                if err is JSErrorDomain { // TODO:
                                    switch err {
                                    case JSErrorDomain.invalidReturnType(let value):
                                        let values: [String] = (self?.adapt(value))!
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
    private func adapt(_ values: Any) -> [String] {
        if let array = values as? [Any] {
            return array.map { String(describing: $0) }
        }
        return []
    }
}
