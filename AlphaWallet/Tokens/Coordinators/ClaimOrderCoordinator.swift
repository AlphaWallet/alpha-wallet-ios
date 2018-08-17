//
// Created by James Sangalli on 7/3/18.
// When someone takes an order and pays for it, we call it "claim an order"
//

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore
import JavaScriptKit
import Result

class ClaimOrderCoordinator {
    private let web3: Web3Swift

    init(
            web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func claimOrder(signedOrder: SignedOrder,
                    expiry: BigUInt,
                    v: UInt8,
                    r: String,
                    s: String,
                    completion: @escaping (Result<String, AnyError>) -> Void
        ) {

        if let tokenIds = signedOrder.order.tokenIds {
            if !tokenIds.isEmpty {
                claimSpawnableOrder(expiry: expiry, tokenIds: tokenIds, v: v, r: r, s: s) { result in
                    completion(result)
                }
            }
            else {
                let request = ClaimERC875Order(expiry: expiry, indices: signedOrder.order.indices, v: v, r: r, s: s)
                web3.request(request: request) { result in
                    switch result {
                            //TODO handle cases for UI
                    case .success(let res):
                        print(res)
                        completion(.success(res))
                    case .failure(let err):
                        print(err)
                        completion(.failure(AnyError(err)))
                    }
                }
            }
        }
    }

    func claimSpawnableOrder(expiry: BigUInt,
                            tokenIds: [BigUInt],
                             v: UInt8,
                             r: String,
                             s: String,
                             completion: @escaping (Result<String, AnyError>) -> Void) {
        let request = ClaimERC875Spawnable(tokenIds: tokenIds, v: v, r: r, s: s, expiry: expiry)
        web3.request(request: request) { result in
            switch result {
                case .success(let res):
                    print(res)
                    completion(.success(res))
                case .failure(let err):
                    print(err)
                    completion(.failure(AnyError(err)))
            }
        }
    }

    // TODO: Testing purposes only. Remove this when it is fully functional
    func startWeb3() {
        web3.start()
    }

}
