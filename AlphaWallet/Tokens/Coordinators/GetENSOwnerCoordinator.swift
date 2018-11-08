//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import Result
import web3swift

class GetENSOwnerCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }
    // Uses Owner(bytes32) where the bytes32 is the hash of the ENS name, e.g. keccak256("microsoft.eth")
    func getENSOwnerFromHash(
            for hash: String,
            completion: @escaping (Result<String, AnyError>) -> Void
    ) {

        guard let webProvider = Web3HttpProvider(config.rpcURL, network: config.server.web3Network) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web provider for: \(config.rpcURL) + \(config.server.web3Network)"))))
            return
        }

        let web3 = web3swift.web3(provider: webProvider)
        let function = GetENSOwnerEncode()
        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: "[\(function.abi)]", at: Constants.ENSRegistrarAddress, options: web3.options) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web3swift contract instance to call \(function.name)()"))))
            return
        }

        guard let promise = contractInstance.method(function.name, options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(Constants.ENSRegistrarAddress.address)"))))
            return
        }
        promise.callPromise(options: nil).done { result in
            if let owner = result["0"] as? String {
                completion(.success(owner))
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(Constants.ENSRegistrarAddress).\(function.name)()"))))
            }
        }.catch { error in
            completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(Constants.ENSRegistrarAddress.address).\(function.name)(): \(error)"))))
        }
    }
}
