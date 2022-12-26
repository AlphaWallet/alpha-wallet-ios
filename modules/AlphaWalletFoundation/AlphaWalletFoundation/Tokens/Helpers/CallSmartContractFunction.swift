// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3
import BigInt

extension RPCServer {
    public var rpcHeaders: RPCNodeHTTPHeaders {
        switch self {
        case .klaytnCypress, .klaytnBaobabTestnet:
            let basicAuth = Constants.Credentials.klaytnRpcNodeKeyBasicAuth
            if basicAuth.isEmpty {
                return .init()
            } else {
                return [
                    "Authorization": "Basic \(basicAuth)",
                    "x-chain-id": "\(chainID)",
                ]
            }
        case .main, .classic, .callisto, .poa, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .cronosTestnet, .arbitrum, .palm, .palmTestnet, .ioTeX, .ioTeXTestnet, .optimismGoerli, .arbitrumGoerli, .cronosMainnet:
            return .init()
        }
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

final class GetEventLogs {
    private let server: RPCServer
    private let queue = DispatchQueue(label: "org.alphawallet.swift.eth.getEventLogs", qos: .utility)
    private var inFlightPromises: [String: Promise<[EventParserResultProtocol]>] = [:]

    init(server: RPCServer) {
        self.server = server
    }

    func getEventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> Promise<[EventParserResultProtocol]> {
        firstly {
            .value(contractAddress)
        }.then(on: queue, { [weak self, queue, server] contractAddress -> Promise<[EventParserResultProtocol]> in
            //It is fine to use the default String representation of `EventFilter` in the cache key. But it is crucial to include it, because the actual variables of the event log fetching are in there. For example ERC1155's `TransferSingle` event is used for fetching both send and receive single token ID events. We can ony tell based on the arguments in `EventFilter` whether it is a send or receive
            let key = "\(contractAddress.eip55String)--\(eventName)-\(abiString)-\(filter)"

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
        }).recover(on: queue, { [server] error -> Promise<[EventParserResultProtocol]> in
            warnLog("[eth_getLogs] failure for server: \(server) with error: \(error)")
            throw error
        })
    }
}
