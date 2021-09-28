// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import web3swift

//TODO time to wrap `callSmartContract` with a class

//TODO wrap callSmartContract() and cache into a type
// swiftlint:disable private_over_fileprivate
fileprivate var smartContractCallsCache = ThreadSafeDictionary<String, (promise: Promise<[String: Any]>, timestamp: Date)>()
fileprivate var web3s = ThreadSafeDictionary<RPCServer, [TimeInterval: web3]>()
// swiftlint:enable private_over_fileprivate

func clearSmartContractCallsCache() {
    web3s.removeAll()
    smartContractCallsCache.removeAll()
}

func getCachedWeb3(forServer server: RPCServer, timeout: TimeInterval) throws -> web3 {
    if let result = web3s[server]?[timeout] {
        return result
    } else {
        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            throw Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)")
        }
        let configuration = webProvider.session.configuration
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        webProvider.session = session

        let result = web3swift.web3(provider: webProvider)
        if var timeoutsAndWeb3s = web3s[server] {
            timeoutsAndWeb3s[timeout] = result
            web3s[server] = timeoutsAndWeb3s
        } else {
            let timeoutsAndWeb3s: [TimeInterval: web3] = [timeout: result]
            web3s[server] = timeoutsAndWeb3s
        }
        return result
    }
}

private let callSmartContractQueue = DispatchQueue(label: "com.callSmartContractQueue.updateQueue")
func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], timeout: TimeInterval? = nil) -> Promise<[String: Any]> {
    let timeout: TimeInterval = 60
    //We must include the ABI string in the key because the order of elements in a dictionary when serialized in the string is not ordered. Parameters (which is ordered) should ensure it's the same function
    let cacheKey = "\(contract).\(functionName) \(parameters) \(server.chainID)"
    let ttlForCache: TimeInterval = 10
    let now = Date()
    if let (cachedPromise, cacheTimestamp) = smartContractCallsCache[cacheKey] {
        let diff = now.timeIntervalSince(cacheTimestamp)
        if diff < ttlForCache {
            //HACK: We can't return the cachedPromise directly and immediately because if we use the value as a TokenScript attribute in a TokenScript view, timing issues will cause the webview to not load properly or for the injection with updates to fail
            return Promise { seal in
                callSmartContractQueue.asyncAfter(deadline: .now() + 0.7) {
                    cachedPromise.done(on: .main) {
                        seal.fulfill($0)
                    }.catch(on: .main) {
                        seal.reject($0)
                    }
                }
            }
        }
    }

    let result: Promise<[String: Any]> = Promise { seal in
        callSmartContractQueue.async {
            guard let web3 = try? getCachedWeb3(forServer: server, timeout: timeout) else {
                seal.reject( Web3Error(description: "Error creating web3 for: \(server.rpcURL) + \(server.web3Network)"))
                return
            }

            let contractAddress = EthereumAddress(address: contract)

            guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
                seal.reject( Web3Error(description: "Error creating web3swift contract instance to call \(functionName)()"))
                return
            }
            guard let promiseCreator = contractInstance.method(functionName, parameters: parameters, options: nil) else {
                seal.reject( Web3Error(description: "Error calling \(contract.eip55String).\(functionName)() with parameters: \(parameters)"))
                return
            }

            //callPromise() creates a promise. It doesn't "call" a promise. Bad name
            promiseCreator.callPromise(options: nil).done(on: .main) { d in
                seal.fulfill(d)
            }.catch(on: .main) { e in
                seal.reject(e)
            }
        }
    }

    smartContractCallsCache[cacheKey] = (result, now)
    return result
}

func getEventLogs(
        withServer server: RPCServer,
        contract: AlphaWallet.Address,
        eventName: String,
        abiString: String,
        filter: EventFilter,
        queue: DispatchQueue
) -> Promise<[EventParserResultProtocol]> {
    firstly { () -> Promise<EthereumAddress> in
        let contractAddress = EthereumAddress(address: contract)
        return .value(contractAddress)
    }.then(on: queue) { contractAddress -> Promise<[EventParserResultProtocol]> in
        guard let web3 = try? getCachedWeb3(forServer: server, timeout: 60) else {
            throw Web3Error(description: "Error creating web3 for: \(server.rpcURL) + \(server.web3Network)")
        }

        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
            return Promise(error: Web3Error(description: "Error creating web3swift contract instance to call \(eventName)()"))
        }

        return contractInstance.getIndexedEventsPromise(eventName: eventName, filter: filter)
    } 
}
