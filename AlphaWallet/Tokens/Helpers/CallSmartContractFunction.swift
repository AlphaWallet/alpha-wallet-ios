// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import web3swift

//TODO maybe we should cache promises that haven't resolved yet. This is useful/needed because users can switch between Wallet and Transactions tab multiple times quickly and trigger the same call to fire many times before any of them have been completed
func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [AnyObject]()) -> Promise<[String: Any]> {
    return firstly { () -> Promise<(EthereumAddress)> in
        let contractAddress = EthereumAddress(address: contract)
        return .value(contractAddress)
    }.then { contractAddress -> Promise<[String: Any]> in
        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            return Promise(error: Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)"))
        }

        let web3 = web3swift.web3(provider: webProvider)

        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
            return Promise(error: Web3Error(description: "Error creating web3swift contract instance to call \(functionName)()"))
        }
        guard let promiseCreator = contractInstance.method(functionName, parameters: parameters, options: nil) else {
            return Promise(error: Web3Error(description: "Error calling \(contract.eip55String).\(functionName)() with parameters: \(parameters)"))
        }

        //callPromise() creates a promise. It doesn't "call" a promise. Bad name
        return promiseCreator.callPromise(options: nil)
    }
}

func getEventLogs(
        withServer server: RPCServer,
        contract: AlphaWallet.Address,
        eventName: String,
        abiString: String,
        filter: EventFilter
) -> Promise<[EventParserResultProtocol]> {
    return firstly { () -> Promise<(EthereumAddress)> in
        let contractAddress = EthereumAddress(address: contract)
        return .value(contractAddress)
    }.then { contractAddress -> Promise<[EventParserResultProtocol]> in
        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            return Promise(error: Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)"))
        }

        let web3 = web3swift.web3(provider: webProvider)

        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
            return Promise(error: Web3Error(description: "Error creating web3swift contract instance to call \(eventName)()"))
        }

        return contractInstance.getIndexedEventsPromise(
                eventName: eventName,
                filter: filter
        )
    }
}
