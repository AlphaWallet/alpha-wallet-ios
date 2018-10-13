//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import Result
import TrustKeystore
import web3swift

class GetERC721BalanceCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func getERC721TokenBalance(
            for address: Address,
            contract: Address,
            completion: @escaping (Result<BigUInt, AnyError>) -> Void
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
        let function = GetERC721Balance()
        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: "[\(function.abi)]", at: contractAddress, options: web3.options) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web3swift contract instance to call \(function.name)()"))))
            return
        }

        guard let promise = contractInstance.method(function.name, parameters: [address.eip55String] as [AnyObject], options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String)"))))
            return
        }
        promise.callPromise(options: nil).done { [weak self] balanceResult in
            guard let strongSelf = self else { return }
            let balance = strongSelf.adapt(balanceResult["0"])
            completion(.success(balance))
        }.catch { error in
            completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)(): \(error)"))))
        }
    }

    private func adapt(_ value: Any) -> BigUInt {
        if let value = value as? BigUInt {
            return value
        } else {
            return BigUInt(0)
        }
    }
}
