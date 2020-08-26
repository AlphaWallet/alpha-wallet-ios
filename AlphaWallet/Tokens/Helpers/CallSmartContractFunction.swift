// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import web3swift

//TODO wrap callSmartContract() and cache into a type
var smartContractCallsCache = [String: (promise: Promise<[String: Any]>, timestamp: Date)]()

func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [AnyObject](), timeout: TimeInterval? = nil) -> Promise<[String: Any]> {
    //We must include the ABI string in the key because the order of elements in a dictionary when serialized in the string is not ordered. Parameters (which is ordered) should ensure it's the same function
    let cacheKey = "\(contract).\(functionName) \(parameters) \(server.chainID)"
    let ttlForCache: TimeInterval = 3
    let now = Date()
    if let (cachedPromise, cacheTimestamp) = smartContractCallsCache[cacheKey] {
        let diff = now.timeIntervalSince(cacheTimestamp)
        if diff < ttlForCache {
            //HACK: We can't return the cachedPromise directly and immediately because if we use the value as a TokenScript attribute in a TokenScript view, timing issues will cause the webview to not load properly or for the injection with updates to fail
            return Promise { seal in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    cachedPromise.done {
                        seal.fulfill($0)
                    }.catch {
                        seal.reject($0)
                    }
                }
            }
        }
    }

    let result: Promise<[String: Any]> = Promise { seal in
        let contractAddress = EthereumAddress(address: contract)
        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            throw Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)")
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
            throw Web3Error(description: "Error creating web3swift contract instance to call \(functionName)()")
        }
        guard let promiseCreator = contractInstance.method(functionName, parameters: parameters, options: nil) else {
            throw Web3Error(description: "Error calling \(contract.eip55String).\(functionName)() with parameters: \(parameters)")
        }

        //callPromise() creates a promise. It doesn't "call" a promise. Bad name
        promiseCreator.callPromise(options: nil).done {
            seal.fulfill($0)
        }.catch {
            seal.reject($0)
        }
    }

    smartContractCallsCache[cacheKey]  = (result, now)
    return result
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
