//
//  NodeApiProvider.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 19.12.2022.
//

import JSONRPCKit
import PromiseKit
import Combine

public protocol ContractMethodCall: CustomStringConvertible {
    associatedtype Response

    var contract: AlphaWallet.Address { get }
    var abi: String { get }
    var name: String { get }
    var parameters: [AnyObject] { get }
    /// Special flag for token script 
    var shouldDelayIfCached: Bool { get }

    func response(from resultObject: Any) throws -> Response
}

extension ContractMethodCall {
    var parameters: [AnyObject] { return [] }
    var shouldDelayIfCached: Bool { return false }

    public var description: String {
        return "contract: \(contract), name: \(name), parameters: \(parameters)"
    }
}

import BigInt
import AlphaWalletWeb3

public protocol NodeApiProvider {
    func dataTaskPromise<R: JSONRPCKit.Request>(_ request: R) -> PromiseKit.Promise<R.Response>
    func dataTaskPublisher<R: JSONRPCKit.Request>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError>

    //NOTE: will be replaced with `dataTaskPromise<R: JSONRPCKit.Request>`
    func dataTaskPromise<R: ContractMethodCall>(_ request: R) -> PromiseKit.Promise<R.Response>
    func dataTaskPublisher<R: ContractMethodCall>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError>
}

public struct RpcHttpParams: Codable {
    public let rpcUrls: [URL]
    public let headers: [String: String]

    public init(rpcUrls: [URL], headers: [String: String]) {
        self.rpcUrls = rpcUrls
        self.headers = headers
    }
}

public struct PrivateNetworkParams: Codable {
    let rpcUrl: URL
    let headers: [String: String]

    public init(rpcUrl: URL, headers: [String: String]) {
        self.rpcUrl = rpcUrl
        self.headers = headers
    }
}

public enum RpcSource: Codable {
    case http(params: RpcHttpParams, privateParams: PrivateNetworkParams?)
    case webSocket(url: URL, privateParams: PrivateNetworkParams?)

    func adding(privateParams: PrivateNetworkParams?) -> RpcSource {
        switch self {
        case .http(let params, _):
            return .http(params: params, privateParams: privateParams)
        case .webSocket(let url, _):
            return .webSocket(url: url, privateParams: privateParams)
        }
    }
}

public protocol NodeApiRequestInterceptor {
    func intercept<R: JSONRPCKit.Request>(request: JsonRpcRequest<R>) -> JsonRpcRequest<R>
}

private class NoInterceptionInterceptor: NodeApiRequestInterceptor {
    func intercept<R: JSONRPCKit.Request>(request: JsonRpcRequest<R>) -> JsonRpcRequest<R> {
        return request
    }
}

class PrivateRpcNodeInterceptor: NodeApiRequestInterceptor {
    //NOTE: might be we can apply private rpc fo any methods, it would be easier, previously it was only when we send trandaction
    var privateNetworkRpcMethods = ["eth_getTransactionCount", "eth_sendRawTransaction"]
    private let privateNetworkParams: PrivateNetworkParams?
    private let server: RPCServer

    init(server: RPCServer, privateNetworkParams: PrivateNetworkParams?) {
        self.server = server
        self.privateNetworkParams = privateNetworkParams
    }

    func intercept<R: JSONRPCKit.Request>(request: JsonRpcRequest<R>) -> JsonRpcRequest<R> {
        guard let params = privateNetworkParams, privateNetworkRpcMethods.contains(request.request.batchElement.request.method) else {
            return request
        }

        return JsonRpcRequest(
            server: server,
            rpcURL: params.rpcUrl,
            rpcHeaders: params.headers,
            request: request.request.batchElement.request)
    }
}

import AlphaWalletCore

private class Web3RpcApiProvider {
    private let server: RPCServer
    private var smartContractCallsCache = AtomicDictionary<String, (promise: Promise<[String: Any]>, timestamp: Date)>()
    private lazy var callSmartContractQueue = DispatchQueue(label: "com.callSmartContractQueue.updateQueue.\(server)")

    init(server: RPCServer) {
        self.server = server
    }

    func dataTaskPromise<R: ContractMethodCall>(_ request: R) -> PromiseKit.Promise<R.Response> {
        attempt(maximumRetryCount: 2, shouldOnlyRetryIf: TokenProvider.shouldRetry(error:)) {
            self.callSmartContract(contract: request.contract, functionName: request.name, abiString: request.abi, parameters: request.parameters, shouldDelayIfCached: request.shouldDelayIfCached)
        }.map { try request.response(from: $0) }
    }

    func dataTaskPublisher<R: ContractMethodCall>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> {
        dataTaskPromise(request)
            .publisher
            .share()
            .mapError { SessionTaskError.responseError($0) }
            .eraseToAnyPublisher()
    }

    private func callSmartContract(contract contractAddress: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], shouldDelayIfCached: Bool = false) -> Promise<[String: Any]> {
        firstly {
            .value(contractAddress)
        }.then(on: callSmartContractQueue, { [smartContractCallsCache, callSmartContractQueue, server] contractAddress -> Promise<[String: Any]> in
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
                        guard case AlphaWalletWeb3.Web3Error.rateLimited = error else { throw error }
                        warnLog("[API] Rate limited by RPC node server: \(server)")

                        throw error
                    })

                smartContractCallsCache[cacheKey] = (promise, now)

                return promise
            }
        })
    }
}

public final class NodeRpcApiProvider: NodeApiProvider {
    private let rpcApiProvider: RpcApiProvider
    private let server: RPCServer
    private let rpcHttpParams: RpcHttpParams
    /// keeps latest rpc url index
    private var rpcUrlIndex: Int = 0
    public var shouldUseNextRpc: (_ error: SessionTaskError) -> Bool = { _ in
        //TODO: update with select next rpc url logic
        return false
    }
    public var requestInterceptor: NodeApiRequestInterceptor = NoInterceptionInterceptor()
    //NOTE: will be removed later
    private lazy var bridgeToWeb3SmartConstractCalls = Web3RpcApiProvider(server: server)

    public init(rpcApiProvider: RpcApiProvider, server: RPCServer, rpcHttpParams: RpcHttpParams) {
        self.server = server
        self.rpcApiProvider = rpcApiProvider
        self.rpcHttpParams = rpcHttpParams
    }

    public func dataTaskPublisher<R: ContractMethodCall>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> {
        bridgeToWeb3SmartConstractCalls
            .dataTaskPublisher(request)
    }

    public func dataTaskPromise<R: ContractMethodCall>(_ request: R) -> PromiseKit.Promise<R.Response> {
        bridgeToWeb3SmartConstractCalls
            .dataTaskPromise(request)
    }

    public func dataTaskPromise<R: JSONRPCKit.Request>(_ request: R) -> PromiseKit.Promise<R.Response> {
        return dataTaskPromise(request, rpcUrlIndex: rpcUrlIndex)
    }

    private func dataTaskPromise<R: JSONRPCKit.Request>(_ request: R, rpcUrlIndex: Int) -> PromiseKit.Promise<R.Response> {
        self.rpcUrlIndex = rpcUrlIndex
        let rpcRequest = buildRpcRequest(with: rpcUrlIndex, for: request)

        return firstly {
            .value(rpcRequest)
        }.map { [requestInterceptor] in requestInterceptor.intercept(request: $0) }
        .then { [rpcApiProvider, shouldUseNextRpc] rpcRequest in
            rpcApiProvider
                .dataTaskPromise(rpcRequest)
                .recover { error -> PromiseKit.Promise<R.Response> in
                    guard let error = error as? SessionTaskError else { return .init(error: error) }

                    if shouldUseNextRpc(error) {
                        return self.dataTaskPromise(request, rpcUrlIndex: rpcUrlIndex + 1)
                    } else {
                        return .init(error: error)
                    }
                }
        }
    }

    public func dataTaskPublisher<R: JSONRPCKit.Request>(_ request: R) -> AnyPublisher<R.Response, SessionTaskError> {
        return dataTaskPublisher(request, rpcUrlIndex: rpcUrlIndex)
    }

    private func dataTaskPublisher<R: JSONRPCKit.Request>(_ request: R, rpcUrlIndex: Int) -> AnyPublisher<R.Response, SessionTaskError> {
        self.rpcUrlIndex = rpcUrlIndex
        let rpcRequest = buildRpcRequest(with: rpcUrlIndex, for: request)

        return Just(rpcRequest)
            .setFailureType(to: SessionTaskError.self)
            .map { [requestInterceptor] in requestInterceptor.intercept(request: $0) }
            .flatMap { [rpcApiProvider, shouldUseNextRpc] rpcRequest in
                rpcApiProvider
                    .dataTaskPublisher(rpcRequest)
                    .catch { error -> AnyPublisher<R.Response, SessionTaskError> in
                        if shouldUseNextRpc(error) {
                            return self.dataTaskPublisher(request, rpcUrlIndex: rpcUrlIndex + 1)
                        } else {
                            return .fail(error)
                        }
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private func buildRpcRequest<R: JSONRPCKit.Request>(with rpcUrlIndex: Int, for request: R) -> JsonRpcRequest<R> {
        return JsonRpcRequest(
            server: server,
            rpcURL: rpcHttpParams.rpcUrls[rpcUrlIndex % rpcHttpParams.rpcUrls.count],
            rpcHeaders: rpcHttpParams.headers,
            request: request)
    }
}
