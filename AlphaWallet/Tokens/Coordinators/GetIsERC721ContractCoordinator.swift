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
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let is721):
                        let request = GetIsERC721Decode(data: is721)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let isERC721):
                                if isERC721 == "true" {
                                    completion(.success(true))
                                }
                                completion(.success(false))
                            case .failure(let error):
                                NSLog("getIsERC721Contract 3 error \(error)")
                                completion(.failure(AnyError(error)))
                            }
                        }
                    case .failure(let error):
                        NSLog("getIsERC721Contract 2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getIsERC721 error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}
