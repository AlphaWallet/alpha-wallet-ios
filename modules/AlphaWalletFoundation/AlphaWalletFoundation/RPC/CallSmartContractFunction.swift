// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletLogger
import AlphaWalletWeb3
import struct AlphaWalletTokenScript.Web3Error
import BigInt
import PromiseKit

extension RPCServer {
    public var rpcHeaders: RPCNodeHTTPHeaders {
        return .init()
    }

    func makeMaximumToBlockForEvents(fromBlockNumber: UInt64) -> EventFilter.Block {
        if let maxRange = maximumBlockRangeForEvents {
            return .blockNumber(fromBlockNumber + maxRange)
        } else {
            return .latest
        }
    }

    var web3SwiftRpcNodeBatchSupportPolicy: JSONRPCrequestDispatcher.DispatchPolicy {
        switch rpcNodeBatchSupport {
        case .noBatching:
            return .NoBatching
        case .batch(let size):
            return .Batch(size)
        }
    }
}

extension Web3 {
    private static var web3s = AtomicDictionary<RPCServer, [TimeInterval: Web3]>()

    private static let web3Queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 32
        queue.underlyingQueue = DispatchQueue.global(qos: .userInteractive)

        return queue
    }()

    private static func createWeb3(webProvider: Web3HttpProvider, forServer server: RPCServer) -> Web3 {
        let requestDispatcher = JSONRPCrequestDispatcher(provider: webProvider, queue: web3Queue.underlyingQueue!, policy: server.web3SwiftRpcNodeBatchSupportPolicy)
        return Web3(provider: webProvider, chainID: BigUInt(server.chainID), queue: web3Queue, requestDispatcher: requestDispatcher)
    }

    public static func instance(for server: RPCServer, timeout: TimeInterval) throws -> Web3 {
        if let result = web3s[server]?[timeout] {
            return result
        } else {
            let rpcHeaders = server.rpcHeaders
            guard let webProvider = Web3HttpProvider(server.rpcURL, headers: rpcHeaders) else {
                throw AlphaWalletTokenScript.Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.chainID)")
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
                let timeoutsAndWeb3s: [TimeInterval: Web3] = [timeout: result]
                web3s[server] = timeoutsAndWeb3s
            }
            return result
        }
    }
}

fileprivate var smartContractCallsCache = AtomicDictionary<String, (promise: Promise<[String: Any]>, timestamp: Date)>()
private let callSmartContractQueue = DispatchQueue(label: "com.callSmartContractQueue.updateQueue")
//`shouldDelayIfCached` is a hack for TokenScript views
//TODO should trap 429 from RPC node
public func callSmartContract(withServer server: RPCServer, contract contractAddress: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], shouldDelayIfCached: Bool = false) -> Promise<[String: Any]> {
    firstly {
        .value(server)
    }.then(on: callSmartContractQueue, { [callSmartContractQueue] server -> Promise<[String: Any]> in
        //cacheKey needs to include the function return type because TokenScript attributes might define it to have different type (and more than 1 type if 2 or more attributes call the same function, for some reason). Without including the return type, subsequent calls will read the cached value but cast to the wrong value if the return type is specified differently. eg. a function call is defined in 2 attributes, 1 with type uint and the other bool, the first call will cache it as `1` and the second call will read it as `false` and not `true`. Caching `abiString` instead of etracting out the return type is just for convenience
        let cacheKey = "\(contractAddress).\(functionName) \(parameters) \(server.chainID) \(abiString)"
        let ttlForCache: TimeInterval = 10
        let now = Date()

        if let (cachedPromise, cacheTimestamp) = smartContractCallsCache[cacheKey], now.timeIntervalSince(cacheTimestamp) < ttlForCache {
            //HACK: We can't return the cachedPromise directly and immediately because if we use the value as a TokenScript attribute in a TokenScript view, timing issues will cause the webview to not load properly or for the injection with updates to fail
            return after(seconds: shouldDelayIfCached ? 0.7 : 0).then(on: callSmartContractQueue, { _ -> Promise<[String: Any]> in return cachedPromise })
        } else {
            let web3 = try Web3.instance(for: server, timeout: 60)
            let contract = try Web3.Contract(web3: web3, abiString: abiString, at: EthereumAddress(address: contractAddress))
            let promiseCreator = try contract.method(functionName, parameters: parameters)

            var web3Options = Web3Options()
            web3Options.excludeZeroGasPrice = server.shouldExcludeZeroGasPrice

            let promise: Promise<[String: Any]> = promiseCreator.callPromise(options: web3Options)
                .recover(on: callSmartContractQueue, { error -> Promise<[String: Any]> in
                    //NOTE: We only want to log rate limit errors above
                    guard case AlphaWalletWeb3.Web3Error.rateLimited = error else {
                        throw error
                    }
                    warnLog("[API] Rate limited by RPC node server: \(server)")

                    throw error
                })

            smartContractCallsCache[cacheKey] = (promise, now)

            return promise
        }
    })
}

public func callSmartContractAsync(withServer server: RPCServer, contract contractAddress: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], shouldDelayIfCached: Bool = false) async throws -> [String: Any] {
    return try await withCheckedThrowingContinuation { continuation in
        firstly {
            callSmartContract(withServer: server, contract: contractAddress, functionName: functionName, abiString: abiString, parameters: parameters)
        }.done {
            continuation.resume(returning: $0)
        }.catch { error in
            continuation.resume(throwing: error)
        }
    }
}

public func getSmartContractCallData(withServer server: RPCServer, contract contractAddress: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = []) -> Data? {
    guard let web3 = try? Web3.instance(for: server, timeout: 60) else { return nil }
    guard let contract = try? Web3.Contract(web3: web3, abiString: abiString, at: EthereumAddress(address: contractAddress), options: web3.options) else { return nil }
    guard let promiseCreator = try? contract.method(functionName, parameters: parameters, options: nil) else { return nil }
    return promiseCreator.data
}

final class GetEventLogs {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.eth.getEventLogs", qos: .utility)
    private var inFlightPromises: [String: Promise<[EventParserResultProtocol]>] = [:]

    func getEventLogs(contractAddress: AlphaWallet.Address, server: RPCServer, eventName: String, abiString: String, filter: EventFilter) -> Promise<[EventParserResultProtocol]> {
        firstly {
            .value(contractAddress)
        }.then(on: queue, { [weak self, queue] contractAddress -> Promise<[EventParserResultProtocol]> in
            //It is fine to use the default String representation of `EventFilter` in the cache key. But it is crucial to include it, because the actual variables of the event log fetching are in there. For example ERC1155's `TransferSingle` event is used for fetching both send and receive single token ID events. We can ony tell based on the arguments in `EventFilter` whether it is a send or receive
            let key = Self.generateEventLogCachingKey(contractAddress: contractAddress, server: server, eventName: eventName, abiString: abiString, filter: filter)

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let web3 = try Web3.instance(for: server, timeout: 60)
                let contract = try Web3.Contract(web3: web3, abiString: abiString, at: EthereumAddress(address: contractAddress), options: web3.options)

                let promise = contract
                    .getIndexedEventsPromise(eventName: eventName, filter: filter)
                    .ensure(on: queue, { self?.inFlightPromises[key] = .none })

                self?.inFlightPromises[key] = promise

                return promise
            }
        }).recover(on: queue, { error -> Promise<[EventParserResultProtocol]> in
            warnLog("[eth_getLogs] failure for server: \(server) with error: \(error)")
            throw error
        })
    }

    //Exposed for testing
    static func generateEventLogCachingKey(contractAddress: AlphaWallet.Address, server: RPCServer, eventName: String, abiString: String, filter: EventFilter) -> String {
        "\(contractAddress.eip55String)-\(server.chainID)-\(eventName)-\(abiString)-\(filter)"
    }
}
