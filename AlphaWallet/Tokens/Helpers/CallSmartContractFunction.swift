// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import TrustKeystore
import web3swift

//TODO maybe we should cache promises that haven't resolved yet. This is useful/needed because users can switch between Wallet and Transactions tab multiple times quickly and trigger the same call to fire many times before any of them have been completed
func callSmartContract(
        withServer server: RPCServer,
        contract: Address,
        functionName: String,
        abiString: String,
        parameters: [AnyObject] = [AnyObject](),
        data: Data = Data()
) -> Promise<[String: Any]> {
    return firstly { () -> Promise<(EthereumAddress)> in
        //EthereumAddress(Data) is much faster than EthereumAddress(String). This is significant because we call this function for each applicable token and there could be hundreds of calls
        guard let data = Data.fromHex(contract.eip55String), let contractAddress = EthereumAddress(data) else {
            return Promise(error: Web3Error(description: "Error converting contract address: \(contract.eip55String)"))
        }

        return .value(contractAddress)
    }.then { contractAddress -> Promise<[String: Any]> in
        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            return Promise(error: Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)"))
        }

        let web3 = web3swift.web3(provider: webProvider)

        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
            return Promise(error: Web3Error(description: "Error creating web3swift contract instance to call \(functionName)()"))
        }

        //if data is provided, use them, else use the parameters.
        //callPromise() creates a promise. It doesn't "call" a promise. Bad name
        if !data.isEmpty {
            guard let promiseCreator = contractInstance.method(extraData: data, options: nil) else {
                return Promise(error: Web3Error(description: "Error calling \(contract.eip55String).\(functionName)() with data: \(data.hex)"))
            }
            return promiseCreator.callPromise(options: nil)
        } else {
            guard let promiseCreator = contractInstance.method(functionName, parameters: parameters, options: nil) else {
                return Promise(error: Web3Error(description: "Error calling \(contract.eip55String).\(functionName)() with parameters: \(parameters)"))
            }
            return promiseCreator.callPromise(options: nil)
        }
    }
}
