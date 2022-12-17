// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletLogger
import AlphaWalletWeb3
import BigInt
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

    var web3SwiftRpcNodeBatchSupportPolicy: DispatchPolicy {
        switch rpcNodeBatchSupport {
        case .noBatching:
            return .noBatching
        case .batch(let size):
            return .batch(size)
        }
    }
}

import AlphaWalletCore

public class CachableContractMethodCallProvider {
    private let rpcRequestProvider: RpcRequestDispatcher
    private let queue = DispatchQueue(label: "org.alphawallet.swift.eth.cached_call", qos: .utility)
    private var cachedResponses: [String: (value: Any, timestamp: Date)] = [:]
    
    public var ttlForCache: TimeInterval = 10

    public init(rpcRequestProvider: RpcRequestDispatcher) {
        self.rpcRequestProvider = rpcRequestProvider
    }

    //TODO: Keep response and not a promise, to avoid memory leaks
    public func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError> {
        Just(method)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, ttlForCache, queue] _ -> AnyPublisher<R.Response, SessionTaskError> in
                guard let strongSelf = self else { return .empty() }

                let cacheKey = "\(method.contract).\(method.name) \(method.parameters) \(method.abi)"
                let now = Date()

                if let (result, cacheTimestamp) = strongSelf.cachedResponses[cacheKey],
                   let result = result as? Swift.Result<R.Response, SessionTaskError>, now.timeIntervalSince(cacheTimestamp) < ttlForCache {
                    //HACK: We can't return the cachedPromise directly and immediately because if we use the value as a TokenScript attribute in a TokenScript view, timing issues will cause the webview to not load properly or for the injection with updates to fail
                    return Just(result)
                        .delay(for: .seconds(method.shouldDelayIfCached ? 0.7 : 0), scheduler: RunLoop.main)
                        .tryMap { result -> R.Response in
                            switch result {
                            case .success(let value):
                                return value
                            case .failure(let error):
                                throw error
                            }
                        }.mapError { SessionTaskError(error: $0) }
                        .eraseToAnyPublisher()
                } else {
                    let publisher = strongSelf.buildCall(method, block: block)
                        .receive(on: queue)
                        .handleEvents(receiveOutput: { value in
                            strongSelf.cachedResponses[cacheKey] = (Swift.Result<R.Response, SessionTaskError>.success(value), now)
                        }, receiveCompletion: { result in
                            guard case .failure(let error) = result else { return }
                            strongSelf.cachedResponses[cacheKey] = (Swift.Result<R.Response, SessionTaskError>.failure(error), now)
                        }).eraseToAnyPublisher()

                    return publisher
                }
            }.eraseToAnyPublisher()
    }

    private func buildCall<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError> {
        do {
            let contract = try Contract(abi: method.abi, address: EthereumAddress(address: method.contract))
            let payload = try contract.methodData(method.name, parameters: method.parameters)

            return rpcRequestProvider
                .send(request: .call(to: method.contract, data: payload))
                .tryMap { try ContractMethodCallDecoder(contract: contract, methodCall: method).decode(response: $0) }
                .mapError { SessionTaskError(error: $0) }
                .eraseToAnyPublisher()
        } catch {
            return .fail(SessionTaskError(error: error))
        }
    }
}

public extension Publisher {
    func mapToOptional() -> AnyPublisher<Output?, Failure> {
        map(Optional.init(_:)).eraseToAnyPublisher()
    }
}

public final class GetEventLogs {
    struct GetEventLogsError: Error, LocalizedError {
        let message: String
        
        public var localizedDescription: String {
            return message
        }
    }
    public typealias EventLogsPublisher = AnyPublisher<[EventParserResultProtocol], SessionTaskError>

    private let queue = DispatchQueue(label: "org.alphawallet.swift.eth.getEventLogs", qos: .utility)
    private var inFlightPromises: [String: EventLogsPublisher] = [:]
    private let rpcRequestProvider: RpcRequestDispatcher

    public init(rpcRequestProvider: RpcRequestDispatcher) {
        self.rpcRequestProvider = rpcRequestProvider
    }

    public func getEventLogs(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> EventLogsPublisher {
        Just(contractAddress)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, rpcRequestProvider, queue] contractAddress -> EventLogsPublisher in
                //It is fine to use the default String representation of `EventFilter` in the cache key. But it is crucial to include it, because the actual variables of the event log fetching are in there. For example ERC1155's `TransferSingle` event is used for fetching both send and receive single token ID events. We can ony tell based on the arguments in `EventFilter` whether it is a send or receive
                let key = Self.generateEventLogCachingKey(contractAddress: contractAddress, eventName: eventName, abiString: abiString, filter: filter)

                if let promise = self?.inFlightPromises[key] {
                    return promise
                } else {
                    do {
                        let contract = try Contract(abi: abiString, address: EthereumAddress(address: contractAddress))

                        guard let params = contract.encodeTopicToGetLogs(eventName: eventName, filter: filter) else {
                            return .fail(.responseError(GetEventLogsError(message: "Unavailable to encode topic")))
                        }

                        let promise = rpcRequestProvider
                            .send(request: .getLogs(params: params))
                            .tryMap { try EventLogsDecoder(contract: contract, eventName: eventName).decode(value: $0) }
                            .mapError { SessionTaskError(error: $0) }
                            .receive(on: queue)
                            .handleEvents(receiveCompletion: { _ in self?.inFlightPromises[key] = nil })
                            .share()
                            .print("xxx.eventLogs: \(contractAddress) eventName: \(eventName)")
                            .eraseToAnyPublisher()

                        self?.inFlightPromises[key] = promise

                        return promise
                    } catch {
                        return .fail(.responseError(error))
                    }
                }
            }.eraseToAnyPublisher()
    }

    //Exposed for testing
    static func generateEventLogCachingKey(contractAddress: AlphaWallet.Address, eventName: String, abiString: String, filter: EventFilter) -> String {
        "\(contractAddress.eip55String)-\(eventName)-\(abiString)-\(filter)"
    }
}
