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
                    completion: @escaping (Result<String, AnyError>) -> Void
        ) {
        let request = ClaimStormBirdOrder(expiry: expiry, indices: indices, v: v, r: r, s: s)
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

    // TODO: Testing purposes only. Remove this when it is fully functional
    func startWeb3() {
        web3.start()
    }

//    let address = "0x276f7Df95428A147C664546600Ef03dCa467b669"
//    let transaction = SignTransaction(
//            value: BigInt("0"),
//            account: .make(address: address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")),
//            to: address,
//            nonce: 9,
//            data: Data(bytes: result),
//            gasPrice: BigInt("20000000000"),
//            gasLimit: BigInt("21000"),
//            chainID: 3
//    )

}
