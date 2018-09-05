//
// Created by James Sangalli on 14/7/18.
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
            completion: @escaping (Result<[BigUInt], AnyError>) -> Void
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

        guard let promise = contractInstance.method(function.name, options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String)"))))
            return
        }
        promise.callPromise(options: nil).done { balanceResult in
            let balances = self.adapt(balanceResult["0"])
            completion(.success(balances))
        }.catch { error in
            completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)()"))))
        }
    }

    private func adapt(_ values: Any) -> [BigUInt] {
        guard let array = values as? [Any] else { return [] }
        return array.map {
            if let val = BigUInt(String(describing: $0)) {
                return val
            } else {
                return BigUInt(0)
            }
        }
    }
}
