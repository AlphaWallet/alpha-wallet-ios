//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import PromiseKit
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
            completion: @escaping (ResultResult<Bool, AnyError>.t) -> Void
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

        guard let cryptoKittyPromise = contractInstance.method(function.name, parameters: [Constants.erc721InterfaceHashOnlyForCryptoKitty] as [AnyObject], options: nil)?.callPromise(options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(Constants.erc721InterfaceHashOnlyForCryptoKitty)"))))
            return
        }

        guard let nonCryptoKittyERC721Promise = contractInstance.method(function.name, parameters: [Constants.erc721InterfaceHash] as [AnyObject], options: nil)?.callPromise(options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(Constants.erc721InterfaceHash)"))))
            return
        }

        //Slower than theoretically possible because we wait for every promise to be resolved. In theory we can stop when any promise is fulfilled with true. But code is much less elegant
        firstly {
            when(resolved: cryptoKittyPromise, nonCryptoKittyERC721Promise)
        }.done { results in
            let cryptoKittyResult = results[0]
            let nonCryptoKittyERC721Result = results[1]
            let isCryptoKitty = cryptoKittyPromise.value?["0"] as? Bool
            let isNonCryptoKittyERC721 = nonCryptoKittyERC721Promise.value?["0"] as? Bool
            if let isCryptoKitty = isCryptoKitty, isCryptoKitty {
                completion(.success(true))
            } else if let isNonCryptoKittyERC721 = isNonCryptoKittyERC721, isNonCryptoKittyERC721 {
                completion(.success(true))
            } else if let isCryptoKitty = isCryptoKitty, let isNonCryptoKittyERC721 = isNonCryptoKittyERC721 {
                completion(.success(false))
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)()"))))
            }
        }
    }
}
