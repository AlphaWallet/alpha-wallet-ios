//
// Created by James Sangalli on 14/7/18.
//

import Foundation
import Result
import TrustKeystore
import web3swift

class GetIsERC721ContractCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func getIsERC721Contract(
            for contract: Address,
            completion: @escaping (Result<Bool, AnyError>) -> Void
    ) {
        guard let contractAddress = EthereumAddress(contract.eip55String) else {
            completion(.failure(AnyError(Web3Error(description: "Error converting contract address: \(contract.eip55String)"))))
            return
        }

        guard let webProvider = Web3HttpProvider(config.rpcURL, network: config.server.web3Network) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web provider for: \(config.rpcURL) + \(config.server.web3Network)"))))
            return
        }

        let web3 = web3swift.web3(provider: webProvider)
        let function = GetIsERC721()
        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: "[\(function.abi)]", at: contractAddress, options: web3.options) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web3swift contract instance to call \(function.name)()"))))
            return
        }

        //TODO Use promise directly instead of DispatchQueue once web3swift pod opens it up
        DispatchQueue.global().async {
            guard let result = contractInstance.method(function.name, parameters: [Constants.erc721InterfaceHash] as [AnyObject], options: nil)?.call(options: nil) else {
                completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String)"))))
                return
            }
            DispatchQueue.main.sync {
                if case .success(let dictionary) = result, let isERC721 = dictionary["0"] as? Bool {
                    completion(.success(isERC721))
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)()"))))
                }
            }
        }
    }
}
