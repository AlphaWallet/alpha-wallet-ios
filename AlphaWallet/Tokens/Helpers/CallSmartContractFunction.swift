// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

//TODO maybe we should cache promises that haven't resolved yet. This is useful/needed because users can switch between Wallet and Transactions tab multiple times quickly and trigger the same call to fire many times before any of them have been completed
func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [AnyObject](), timeout: TimeInterval? = nil) -> Promise<[String: Any]> {
    return firstly { () -> Promise<(EthereumAddress)> in
        let contractAddress = EthereumAddress(address: contract)
        return .value(contractAddress)
    }.then { contractAddress -> Promise<[String: Any]> in
        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            return Promise(error: Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)"))
        }
        if let timeout = timeout {
            let configuration = webProvider.session.configuration
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            let session = URLSession(configuration: configuration)
            webProvider.session = session
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
    firstly { () -> Promise<(EthereumAddress)> in
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

//TODO fix for activities: tidy up. Need a class?
class GetBlockTimestamp {
    //TODO fix for activities: move
    private static var blockTimestampCache: [RPCServer: [BigUInt: Date]] = .init()

    func getBlockTimestamp(_ blockNumber: BigUInt, onServer server: RPCServer) -> Promise<Date> {
        var cacheForServer = GetBlockTimestamp.blockTimestampCache[server] ?? .init()
        if let date = cacheForServer[blockNumber] {
            return .value(date)
        }

        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            return Promise(error: Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)"))
        }
        let web3 = web3swift.web3(provider: webProvider)
        return web3.eth.getBlockByNumberPromise(blockNumber).map {
            let result = $0.timestamp
            cacheForServer[blockNumber] = result
            GetBlockTimestamp.blockTimestampCache[server] = cacheForServer
            return result
        }
    }
}
