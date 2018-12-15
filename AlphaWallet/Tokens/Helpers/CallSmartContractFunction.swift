// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import TrustKeystore
import web3swift

func callSmartContract(withConfig config: Config, contract: Address, functionName: String, abiString: String, parameters: [AnyObject] = [AnyObject]()) -> Promise<[String: Any]> {
    guard let contractAddress = EthereumAddress(contract.eip55String) else {
        return Promise(error: Web3Error(description: "Error converting contract address: \(contract.eip55String)"))
    }

    guard let webProvider = Web3HttpProvider(config.rpcURL, network: config.server.web3Network) else {
        return Promise(error: Web3Error(description: "Error creating web provider for: \(config.rpcURL) + \(config.server.web3Network)"))
    }

    let web3 = web3swift.web3(provider: webProvider)
    guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
        return Promise(error: Web3Error(description: "Error creating web3swift contract instance to call \(functionName)()"))
    }

    guard let promise = contractInstance.method(functionName, parameters: parameters, options: nil) else {
        return Promise(error: Web3Error(description: "Error calling \(contract.eip55String).\(functionName)() with parameters: \(parameters)"))
    }

    return promise.callPromise(options: nil)
}
