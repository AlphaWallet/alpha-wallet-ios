//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import Result
import web3swift
import CryptoSwift

//https://github.com/ethereum/EIPs/blob/master/EIPS/eip-137.md
extension String {
    var nameHash: String {
        var node = Array<UInt8>.init(repeating: 0x0, count: 32)
        if !self.isEmpty {
            node = self.split(separator: ".")
                .map { Array($0.utf8).sha3(.keccak256) }
                .reversed()
                .reduce(node) { return ($0 + $1).sha3(.keccak256) }
        }
        return "0x" + node.toHexString()
    }
}

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

        //if it does not contain .eth, then it is not a valid ens name
        if !input.contains(".") {
            completion(.failure(AnyError(Web3Error(description: "Invalid ENS Name"))))
            return
        }

        let node = input.lowercased().nameHash

        guard let webProvider = Web3HttpProvider(config.rpcURL, network: config.server.web3Network) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web provider for: \(config.rpcURL) + \(config.server.web3Network)"))))
            return
        }

        let web3 = web3swift.web3(provider: webProvider)
        let function = GetENSOwnerEncode()
        let contractAddress = getENSAddress(networkId: config.chainID)
        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: "[\(function.abi)]", at: contractAddress, options: web3.options) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web3swift contract instance to call \(function.name)()"))))
            return
        }

        guard let promise = contractInstance.method(function.name, parameters: [node] as [AnyObject], options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contractAddress.address)"))))
            return
        }

        promise.callPromise(options: nil).done { result in
            //if null address is returned (as 0) we count it as invalid
            //this is because it is not assigned to an ENS and puts the user in danger of sending funds to null
            if let owner = result["0"] as? EthereumAddress {
                if owner.address == Constants.nullAddress {
                    completion(.failure(AnyError(Web3Error(description: "Null address returned"))))
                } else {
                    completion(.success(owner))
                }
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contractAddress.address).\(function.name)()"))))
            }
        }.catch { error in
            completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contractAddress.address).\(function.name)(): \(error)"))))
        }
    }

    private func getENSAddress(networkId: Int) -> EthereumAddress {
        switch networkId {
        case 1: return Constants.ENSRegistrarAddress
        case 3: return Constants.ENSRegistrarRopsten
        case 4: return Constants.ENSRegistrarRinkeby
        default: return Constants.ENSRegistrarAddress
        }
    }
    
}
