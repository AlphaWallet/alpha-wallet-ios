// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import web3swift

//TODO time to wrap `callSmartContract` with a class

//TODO wrap callSmartContract() and cache into a type
// swiftlint:disable private_over_fileprivate
fileprivate var smartContractCallsCache = AtomicDictionary<String, (promise: Promise<[String: Any]>, timestamp: Date)>()
fileprivate var web3s = AtomicDictionary<RPCServer, [TimeInterval: web3]>()
// swiftlint:enable private_over_fileprivate

private let web3Queue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 32
    queue.underlyingQueue = DispatchQueue.global(qos: .userInteractive)

    return queue
}()

private func createWeb3(webProvider: Web3HttpProvider, forServer server: RPCServer) -> web3 {
    let requestDispatcher = JSONRPCrequestDispatcher(provider: webProvider, queue: web3Queue.underlyingQueue!, policy: server.web3SwiftRpcNodeBatchSupportPolicy)
    return web3swift.web3(provider: webProvider, queue: web3Queue, requestDispatcher: requestDispatcher)
}

public func getCachedWeb3(forServer server: RPCServer, timeout: TimeInterval) throws -> web3 {
    if let result = web3s[server]?[timeout] {
        return result
    } else {
        let rpcHeaders = server.rpcHeaders
        guard let webProvider = Web3HttpProvider(server.rpcURL, headers: rpcHeaders, network: server.web3Network) else {
            throw Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)")
        }
        let configuration = webProvider.session.configuration
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        webProvider.session = session

        let result = createWeb3(webProvider: webProvider, forServer: server)
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
//`shouldDelayIfCached` is a hack for TokenScript views
//TODO should trap 429 from RPC node
public func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], shouldDelayIfCached: Bool = false, queue: DispatchQueue? = nil) -> Promise<[String: Any]> {
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
                let delay: Double = shouldDelayIfCached ? 0.7 : 0
                callSmartContractQueue.asyncAfter(deadline: .now() + delay) {
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
                seal.reject(Web3Error(description: "Error creating web3 for: \(server.rpcURL) + \(server.web3Network)"))
                return
            }

            let contractAddress = EthereumAddress(address: contract)

            guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
                seal.reject(Web3Error(description: "Error creating web3swift contract instance to call \(functionName)()"))
                return
            }
            guard let promiseCreator = contractInstance.method(functionName, parameters: parameters, options: nil) else {
                seal.reject(Web3Error(description: "Error calling \(contract.eip55String).\(functionName)() with parameters: \(parameters)"))
                return
            }
            var web3Options = Web3Options()
            web3Options.excludeZeroGasPrice = server.shouldExcludeZeroGasPrice

            //callPromise() creates a promise. It doesn't "call" a promise. Bad name
            firstly {
                promiseCreator.callPromise(options: web3Options)
            }.done(on: queue ?? .main, { d in
                seal.fulfill(d)
            }).catch(on: queue ?? .main, { e in
                if let e  = e as? web3swift.Web3Error {
                    switch e {
                    case .rateLimited:
                        warnLog("[API] Rate limited by RPC node server: \(server)")
                    case .transactionSerializationError, .connectionError, .dataError, .walletError, .inputError, .nodeError, .processingError, .keystoreError, .generalError, .unknownError:
                        //no-op. We only want to log rate limit errors above
                        break
                    }
                } else {
                    //no-op
                }
                seal.reject(e)
            })
        }
    }

    smartContractCallsCache[cacheKey] = (result, now)
    return result
}

public func getSmartContractCallData(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = []) -> Data? {
    //TODO should be extracted. Duplicated
    let timeout: TimeInterval = 60
    guard let web3 = try? getCachedWeb3(forServer: server, timeout: timeout) else { return nil }
    let contractAddress = EthereumAddress(address: contract)
    guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else { return nil }
    guard let promiseCreator = contractInstance.method(functionName, parameters: parameters, options: nil) else { return nil }
    return promiseCreator.transaction.data
}

public func getEventLogs(
        withServer server: RPCServer,
        contract: AlphaWallet.Address,
        eventName: String,
        abiString: String,
        filter: EventFilter,
        queue: DispatchQueue
) -> Promise<[EventParserResultProtocol]> {
    let contractAddress = EthereumAddress(address: contract)

    guard let web3 = try? getCachedWeb3(forServer: server, timeout: 60) else {
        return Promise(error: Web3Error(description: "Error creating web3 for: \(server.rpcURL) + \(server.web3Network)"))
    }

    guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: abiString, at: contractAddress, options: web3.options) else {
        return Promise(error: Web3Error(description: "Error creating web3swift contract instance to call \(eventName)()"))
    }

    return contractInstance.getIndexedEventsPromise(eventName: eventName, filter: filter)
        .recover { error -> Promise<[EventParserResultProtocol]> in
            warnLog("[eth_getLogs] failure for server: \(server) with error: \(error)")
            return .init(error: error)
        }
}

func createSmartContractCallError(forContract contract: AlphaWallet.Address, functionName: String) -> Error {
    Web3Error(description: "Error extracting result from \(contract.eip55String).\(functionName)()")
}

func createABIError(_ erorr: ABIError) -> Error {
    erorr
}
