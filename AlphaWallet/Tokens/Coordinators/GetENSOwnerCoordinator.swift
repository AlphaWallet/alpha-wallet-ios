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

    func getENSOwner(
            for input: String,
            completion: @escaping (Result<EthereumAddress, AnyError>) -> Void
    ) {

        //if already an address, send back the address
        if let ethAddress = EthereumAddress(input) {
            completion(.success(ethAddress))
            return
        }

        let hashedInput = web3swift.Web3Utils.keccak256(Data(input.utf8))

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

        guard let promise = contractInstance.method(function.name, parameters: [hashedInput] as [AnyObject], options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(Constants.ENSRegistrarAddress.address)"))))
            return
        }

        promise.callPromise(options: nil).done { result in
            if let owner = result["0"] as? String {
                guard let ownerAddress = EthereumAddress(owner) else {
                    completion(.failure(AnyError(Web3Error(description: "Invalid address"))))
                    return
                }
                completion(.success(ownerAddress))
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(Constants.ENSRegistrarAddress).\(function.name)()"))))
            }
        }.catch { error in
            completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(Constants.ENSRegistrarAddress.address).\(function.name)(): \(error)"))))
        }
    }
}
