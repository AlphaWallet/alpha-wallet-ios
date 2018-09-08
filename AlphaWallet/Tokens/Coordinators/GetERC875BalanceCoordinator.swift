import Foundation
import Result
import TrustKeystore
import web3swift

class GetERC875BalanceCoordinator {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func getERC875TokenBalance(
        for address: Address,
        contract: Address,
        completion: @escaping (Result<[String], AnyError>) -> Void
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
        let function = GetERC875Balance()
        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: "[\(function.abi)]", at: contractAddress, options: web3.options) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web3swift contract instance to call \(function.name)()"))))
            return
        }

        guard let promise = contractInstance.method(function.name, parameters: [address.eip55String] as [AnyObject], options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(contractInstance).\(function.name)() of \(address.eip55String) as ERC875"))))
            return
        }
        promise.callPromise(options: nil).done { balanceResult in
            let balances = self.adapt(balanceResult["0"])
            completion(.success(balances))
        }.catch { error in
            completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contractInstance).\(function.name)() of \(address.eip55String) as ERC875"))))
        }
    }

    private func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [Data] else { return [] }
        return array.map { each in
            let value = each.toHexString()
            return "0x\(value)"
        }
    }
}
