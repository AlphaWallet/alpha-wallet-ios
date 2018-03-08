//
// Created by James Sangalli on 7/3/18.
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

    func claimOrder(indices: [UInt16],
                    expiry: BigUInt,
                    v: UInt8,
                    r: String,
                    s: String,
                    completion: @escaping (Result<Void, AnyError>) -> Void
    ) {
        let request = ClaimStormBirdOrder(expiry: expiry, indices: indices, v: v, r: r, s: s)
        web3.request(request: request) { result in
            switch result {
                //TODO handle cases for UI
                case .success(let res):
                    print(res)
                    //completion(res)
                case .failure(let err):
                    print(err)
                    //completion(err)
            }

        }
    }
}
