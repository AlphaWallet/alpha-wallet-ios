//
// Created by James Sangalli on 14/7/18.
//

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class GetIsERC721ContractCoordinator {
    private let web3: Web3Swift

    init(
            web3: Web3Swift
    ) {
        self.web3 = web3
    }

    func getIsERC721Contract(
            for contract: Address,
            completion: @escaping (Result<Bool, AnyError>) -> Void
    ) {
        let request = GetIsERC721Encode()
        web3.request(request: request) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                NSLog("getIsERC721 error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}
