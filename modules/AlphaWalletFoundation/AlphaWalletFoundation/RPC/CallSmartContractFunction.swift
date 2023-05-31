// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletLogger
import AlphaWalletWeb3
import BigInt
import AlphaWalletCore
import Combine

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
                throw Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.chainID)")
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

class CallSmartContract {
    typealias Publisher = AnyPublisher<[String: Any], SessionTaskError>
    private let server: RPCServer
    private let queue = DispatchQueue(label: "org.alphawallet.swift.eth_call", qos: .utility)
    private var inFlightPublishers: [String: Publisher] = [:]
    private var cache: [String: (result: Swift.Result<[String: Any], SessionTaskError>, timestamp: Date)] = [:]
    private let web3: Web3?
    private lazy var web3Options: Web3Options = {
        var web3Options = Web3Options()
        web3Options.excludeZeroGasPrice = server.shouldExcludeZeroGasPrice

        return web3Options
    }()

    init(server: RPCServer) {
        self.server = server
        self.web3 = try? Web3.instance(for: server, timeout: 60)
    }

    func clean() {
        cache.removeAll()
        inFlightPublishers.removeAll()
    }

    func call(contractAddress: AlphaWallet.Address,
              functionName: String,
              abiString: String,
              parameters: [AnyObject] = [],
              shouldDelayIfCached: Bool = false) -> Publisher {

        //cacheKey needs to include the function return type because TokenScript attributes might define it to have different type (and more than 1 type if 2 or more attributes call the same function, for some reason). Without including the return type, subsequent calls will read the cached value but cast to the wrong value if the return type is specified differently. eg. a function call is defined in 2 attributes, 1 with type uint and the other bool, the first call will cache it as `1` and the second call will read it as `false` and not `true`. Caching `abiString` instead of etracting out the return type is just for convenience
        let cacheKey = "\(contractAddress).\(functionName) \(parameters) \(server.chainID) \(abiString)"

        return Just(cacheKey)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, web3Options] cacheKey -> Publisher in
                guard let strongSelf = self else { return .empty() }
                guard let web3 = strongSelf.web3 else { return .empty() }

                if let publisher = strongSelf.loadFromCache(cacheKey: cacheKey, shouldDelayIfCached: shouldDelayIfCached) {
                    return publisher
                } else if let publisher = strongSelf.inFlightPublishers[cacheKey] {
                    return publisher
                } else {
                    let publisher = Just(web3Options)
                        .setFailureType(to: PromiseError.self)
                        .tryMap { _ in
                            let contract = try Web3.Contract(web3: web3, abiString: abiString, at: EthereumAddress(address: contractAddress))
                            return try contract.method(functionName, parameters: parameters)
                        }.mapError { PromiseError(error: $0) }
                        .flatMap { $0.callPromise(options: web3Options).publisher(queue: queue) }
                        .mapError { SessionTaskError(error: $0.embedded) }
                        .receive(on: queue)
                        .handleEvents(receiveOutput: { value in
                            strongSelf.cache[cacheKey] = (.success(value), Date())
                        }, receiveCompletion: { result in
                            strongSelf.inFlightPublishers[cacheKey] = nil

                            if case .failure(let error) = result {
                                strongSelf.cache[cacheKey] = (.failure(error), Date())
                            }
                        })
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPublishers[cacheKey] = publisher

                    return publisher
                }
            }.handleEvents(receiveCompletion: { [server] result in
                guard case .failure(let error) = result else { return }
                    //NOTE: We only want to log rate limit errors above
                guard case AlphaWalletWeb3.Web3Error.rateLimited = error.unwrapped else { return }
                warnLog("[API] Rate limited by RPC node server: \(server)")
            }).eraseToAnyPublisher()
    }

    private func loadFromCache(cacheKey: String, shouldDelayIfCached: Bool) -> Publisher? {
        let now = Date()
        let ttlForCache: TimeInterval = 10

        if let (cached, cacheTimestamp) = cache[cacheKey], now.timeIntervalSince(cacheTimestamp) < ttlForCache {
            //HACK: We can't return the cachedPromise directly and immediately because if we use the value as a TokenScript attribute in a TokenScript view, timing issues will cause the webview to not load properly or for the injection with updates to fail
            return Just(cached)
                .delay(for: .milliseconds(shouldDelayIfCached ? 700 : 0), scheduler: RunLoop.main)
                .tryMap { try $0.get() }
                .mapError { SessionTaskError(error: $0) }
                .eraseToAnyPublisher()
        }

        return nil
    }
}

public func getSmartContractCallData(withServer server: RPCServer, contract contractAddress: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = []) -> Data? {
    guard let web3 = try? Web3.instance(for: server, timeout: 60) else { return nil }
    guard let contract = try? Web3.Contract(web3: web3, abiString: abiString, at: EthereumAddress(address: contractAddress), options: web3.options) else { return nil }
    guard let promiseCreator = try? contract.method(functionName, parameters: parameters, options: nil) else { return nil }
    return promiseCreator.transaction.data
}
