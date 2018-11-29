//
// Created by James Sangalli on 7/3/18.
// Copyright © 2018 Stormbird PTE. LTD.
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

    init(web3: Web3Swift) {
        self.web3 = web3
    }

    func claimOrder(signedOrder: SignedOrder,
                    expiry: BigUInt,
                    v: UInt8,
                    r: String,
                    s: String,
                    contractAddress: String,
                    recipient: String,
                    completion: @escaping (Result<String, AnyError>) -> Void
        ) {

        if let tokenIds = signedOrder.order.tokenIds, !tokenIds.isEmpty {
            claimSpawnableOrder(expiry: expiry, tokenIds: tokenIds, v: v, r: r, s: s, recipient: recipient) { result in
                completion(result)
            }
        } else {
            claimNormalOrder(expiry: expiry, indices: signedOrder.order.indices, v: v, r: r, s: s, contractAddress: contractAddress) { result in
                completion(result)
            }
        }
    }
    
    func claimNormalOrder(expiry: BigUInt,
                          indices: [UInt16],
                          v: UInt8,
                          r: String,
                          s: String,
                          contractAddress: String,
                          completion: @escaping (Result<String, AnyError>) -> Void) {
        let request = ClaimERC875Order(expiry: expiry, indices: indices, v: v, r: r, s: s, contractAddress: contractAddress)
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

    func claimSpawnableOrder(expiry: BigUInt,
                             tokenIds: [BigUInt],
                             v: UInt8,
                             r: String,
                             s: String,
                             recipient: String,
                             completion: @escaping (Result<String, AnyError>) -> Void) {
        let request = ClaimERC875Spawnable(tokenIds: tokenIds, v: v, r: r, s: s, expiry: expiry, recipient: recipient)
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
