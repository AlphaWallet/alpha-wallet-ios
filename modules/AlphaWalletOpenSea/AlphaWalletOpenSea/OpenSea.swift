//
//  OpenSea.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/29/22.
//

import AlphaWalletAddress
import AlphaWalletCore
import SwiftyJSON
import Alamofire
import Combine

public typealias OpenSeaAddressesToNonFungibles = [AlphaWallet.Address: [NftAsset]]

public protocol OpenSeaDelegate: AnyObject {
    func openSeaError(error: OpenSeaApiError)
}

public enum OpenSeaApiError: Error {
    case `internal`(Error)
    case invalidJson
    case rateLimited
    case invalidApiKey
    case expiredApiKey
}

extension OpenSeaApiError {
    init(error: Error) {
        if let e = error as? OpenSeaApiError {
            self = e
        } else {
            self = .internal(error)
        }
    }
}

public typealias Request = Alamofire.URLRequestConvertible

public protocol Networking {
    //TODO reduce usage and remove
    func send(request: Request) -> AnyPublisher<URLRequest.Response, PromiseError>
    func sendAsync(request: Request) async throws -> URLRequest.Response
}

final class OpenSeaRetryPolicy: RetryPolicy {

    init() {
        super.init(retryableHTTPStatusCodes: Set([429, 408, 500, 502, 503, 504]))
    }

    override func retry(_ request: Alamofire.Request,
                        for session: Session,
                        dueTo error: Error,
                        completion: @escaping (RetryResult) -> Void) {

        if request.retryCount < retryLimit, shouldRetry(request: request, dueTo: error) {
            if let httpResponse = request.response, let delay = OpenSeaRetryPolicy.retryDelay(from: httpResponse) {
                completion(.retryWithDelay(delay))
            } else {
                completion(.retryWithDelay(pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale))
            }
        } else {
            completion(.doNotRetry)
        }
    }

    private static func retryDelay(from httpResponse: HTTPURLResponse) -> TimeInterval? {
        (httpResponse.allHeaderFields["retry-after"] as? String).flatMap { TimeInterval($0) }
    }
}

public class OpenSeaNetworking: Networking {

    //Important to be static so it's for *all* OpenSea calls
    private static let callCounter = CallCounter()
    private let rootQueue = DispatchQueue(label: "org.alamofire.customQueue")
    private let session: Session

    var maxPublishers: Int = 3//max concurrent tasks

    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true

        let policy = OpenSeaRetryPolicy()

        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { request, _ in
            DispatchQueue.main.async {
                OpenSeaNetworking.callCounter.clock()
                let url = request.lastRequest?.url?.absoluteString
                infoLog("[OpenSea] Accessing url: \(url) rate: \(OpenSeaNetworking.callCounter.averageRatePerSecond)/sec")
            }
        }

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.underlyingQueue = rootQueue

        let delegate = SessionDelegate()
        let urlSession = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: queue)

        session = Session(
            session: urlSession,
            delegate: delegate,
            rootQueue: rootQueue,
            interceptor: policy,
            eventMonitors: [monitor])
    }

    struct NonHttpUrlResponseError: Error {
        let request: Request
    }

    public func send(request: Request) -> AnyPublisher<URLRequest.Response, PromiseError> {
        Just(request)
            .setFailureType(to: PromiseError.self)
            .flatMap(maxPublishers: .max(maxPublishers)) { [session, rootQueue] request in
                session.request(request)
                    .validate()
                    .publishData(queue: rootQueue)
                    .tryMap { respose in
                        if let data = respose.data, let httpResponse = respose.response {
                            return (data: data, response: httpResponse)
                        } else {
                            throw PromiseError(error: NonHttpUrlResponseError(request: request))
                        }
                    }.mapError { PromiseError(error: $0) }
            }.eraseToAnyPublisher()
    }

    //TODO there was a maximum of 3 concurrent requests in the non-async implementation
    public func sendAsync(request: Request) async throws -> URLRequest.Response {
        let response = try await session.request(request).serializingData().response
        if let data = response.data, let httpResponse = response.response {
            return (data: data, response: httpResponse)
        } else {
            throw NonHttpUrlResponseError(request: request)
        }
    }
}

public protocol OpenSeaNetworkingFactory {
    func networking(for server: RPCServer) -> Networking
}

public final class BaseOpenSeaNetworkingFactory: OpenSeaNetworkingFactory {
    private var networkings: [URL: Networking] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.atomicDictionary", qos: .background)

    public static let shared = BaseOpenSeaNetworkingFactory()
    private init() { }

    public func networking(for server: RPCServer) -> Networking {
        var networking: Networking!

        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            let baseUrl = OpenSea.getBaseUrlForOpenSea(forServer: server)
            if let _networking = self.networkings[baseUrl] {
                networking = _networking
            } else {
                networking = OpenSeaNetworking()
                self.networkings[baseUrl] = networking
            }
        }

        return networking
    }
}

public class OpenSea {
    public static var isLoggingEnabled = false
    private let networking: OpenSeaNetworkingFactory
    private let apiKeys: [RPCServer: String]

    weak public var delegate: OpenSeaDelegate?

    public init(apiKeys: [RPCServer: String], networking: OpenSeaNetworkingFactory = BaseOpenSeaNetworkingFactory.shared) {
        self.apiKeys = apiKeys
        self.networking = networking
    }

    public func fetchAssetsCollections(owner: AlphaWallet.Address, server: RPCServer, excludeContracts: [(AlphaWallet.Address, RPCServer)]) -> AnyPublisher<Response<OpenSeaAddressesToNonFungibles>, Never> {
        //NOTE: some of OpenSea collections have an empty `primary_asset_contracts` array, so we are not able to identifyto each asset connection relates. it solves with `slug` field for collection. We match assets `slug` with collections `slug` values for identification
        func findCollection(address: AlphaWallet.Address, asset: NftAsset, collections: [CollectionKey: AlphaWalletOpenSea.NftCollection]) -> AlphaWalletOpenSea.NftCollection? {
            return collections[.address(address)] ?? collections[.collectionId(asset.collectionId)]
        }

        //NOTE: Due to OpenSea's policy of sending requests, (we are not able to sent multiple requests, the request trottled, and 1 sec delay is needed)
        //to send a new one. First we send fetch assets requests and then fetch collections requests

        let assets = fetchAssets(owner: owner, server: server, excludeContracts: excludeContracts)
        let collections = fetchCollections(owner: owner, server: server)

        return Publishers.CombineLatest(assets, collections)
            .map { assets, collections in
                var result: [AlphaWallet.Address: [NftAsset]] = [:]
                for asset in assets.result {
                    let updatedElements = asset.value.map { _asset -> NftAsset in
                        var _asset = _asset
                        let collection = findCollection(address: asset.key, asset: _asset, collections: collections.result)
                        _asset.collection = collection

                        return _asset
                    }

                    result[asset.key] = updatedElements
                }
                let hasError = assets.hasError || collections.hasError

                return .init(hasError: hasError, result: result)
            }.eraseToAnyPublisher()
    }

    static func getBaseUrlForOpenSea(forServer server: RPCServer) -> URL {
        switch server {
        case .main:
            return URL(string: "https://api.opensea.io")!
        default:
            return URL(string: "https://api.opensea.io")!
        }
    }

    private func openSeaKey(forServer server: RPCServer) -> String? {
        return apiKeys[server]
    }

    public func fetchAsset(asset: String, server: RPCServer) async throws -> NftAsset {
        let request = AssetRequest(baseUrl: Self.getBaseUrlForOpenSea(forServer: server), apiKey: openSeaKey(forServer: server) ?? "", server: server, asset: asset)
        let json = try await sendAsync(request: request, server: server)
        if let asset = NftAsset(json: json) {
            return asset
        } else {
            throw OpenSeaApiError.invalidJson
        }
    }

    public func collectionStats(collectionId: String, server: RPCServer) -> AnyPublisher<NftCollectionStats, PromiseError> {
        let request = CollectionStatsRequest(
            baseUrl: Self.getBaseUrlForOpenSea(forServer: server),
            apiKey: openSeaKey(forServer: server) ?? "",
            collectionId: collectionId)

        return send(request: request, server: server)
            .mapError { PromiseError(error: $0) }
            .flatMap { json -> AnyPublisher<NftCollectionStats, PromiseError> in
                if json["stats"] != .null {
                    return .just(NftCollectionStats(json: json["stats"]))
                } else {
                    return .fail(PromiseError(error: OpenSeaApiError.invalidJson))
                }
            }.eraseToAnyPublisher()
    }

    private func fetchCollections(owner: AlphaWallet.Address, server: RPCServer, offset: Int = 0, collections: [CollectionKey: NftCollection] = [:]) -> AnyPublisher<Response<[CollectionKey: NftCollection]>, Never> {
        let request = CollectionsRequest(
            baseUrl: Self.getBaseUrlForOpenSea(forServer: server),
            apiKey: openSeaKey(forServer: server) ?? "",
            server: server,
            offset: offset,
            owner: owner)

        let decoder = OpenSeaCollectionDecoder(collections: collections)

        return send(request: request, server: server)
            .map { decoder.decode(json: $0) }
            .catch { error -> AnyPublisher<NftCollectionsPage, Never> in
                return .just(.init(collections: [:], count: 0, hasNextPage: false, error: error))
            }.flatMap { [weak self] result -> AnyPublisher<Response<[CollectionKey: NftCollection]>, Never> in
                guard let strongSelf = self else { return .empty() }

                if result.hasNextPage {
                    return strongSelf.fetchCollections(owner: owner, server: server, offset: offset + result.count, collections: result.collections)
                } else {
                    return .just(.init(hasError: result.error != nil, result: result.collections))
                }
            }.eraseToAnyPublisher()
    }

    private struct JsonDecoder {
        func decode(data: URLRequest.Response) throws -> JSON {
            let statusCode = data.response.statusCode
            if statusCode == 401 {
                if let body = String(data: data.data, encoding: .utf8), body.contains("Expired API key") {
                    throw OpenSeaApiError.expiredApiKey
                } else {
                    throw OpenSeaApiError.invalidApiKey
                }
            } else if statusCode == 429 {
                throw OpenSeaApiError.rateLimited
            }

            if let json = try? JSON(data: data.data) {
                return json
            } else {
                throw OpenSeaApiError.invalidJson
            }
        }
    }

    //TODO reduce usage and remove
    private func send(request: Alamofire.URLRequestConvertible, server: RPCServer) -> AnyPublisher<JSON, OpenSeaApiError> {
        networking.networking(for: server)
            .send(request: request)
            .tryMap { try JsonDecoder().decode(data: $0) }
            .mapError { OpenSeaApiError(error: $0) }
            .eraseToAnyPublisher()
    }

    private func sendAsync(request: Alamofire.URLRequestConvertible, server: RPCServer) async throws -> JSON {
        let response = try await networking.networking(for: server).sendAsync(request: request)
        return try JsonDecoder().decode(data: response)
    }

    private func fetchAssets(owner: AlphaWallet.Address, server: RPCServer, next: String? = nil, assets: OpenSeaAddressesToNonFungibles = [:], excludeContracts: [(AlphaWallet.Address, RPCServer)]) -> AnyPublisher<Response<OpenSeaAddressesToNonFungibles>, Never> {
        let request: Alamofire.URLRequestConvertible
        if let cursorUrl = next {
            request = AssetsCursorRequest(
                apiKey: openSeaKey(forServer: server) ?? "",
                cursorUrl: cursorUrl)
        } else {
            request = AssetsRequest(
                baseUrl: Self.getBaseUrlForOpenSea(forServer: server),
                owner: owner,
                apiKey: openSeaKey(forServer: server) ?? "",
                server: server)
        }

        let decoder = NftAssetsPageDecoder(assets: assets)

        return send(request: request, server: server)
            .map { decoder.decode(json: $0) }
            .catch { error -> AnyPublisher<NftAssetsPage, Never> in
                let assetsExcluding = NftAssetsFilter(assets: assets).assets(excludeing: excludeContracts)
                return .just(.init(assets: assetsExcluding, count: 0, next: nil, error: error))
            }.flatMap { [weak self] result -> AnyPublisher<Response<OpenSeaAddressesToNonFungibles>, Never> in
                guard let strongSelf = self else { return .empty() }

                if let next = result.next {
                    return strongSelf.fetchAssets(
                        owner: owner,
                        server: server,
                        next: next,
                        assets: result.assets,
                        excludeContracts: excludeContracts)
                } else {
                    let assetsExcluding = NftAssetsFilter(assets: result.assets).assets(excludeing: excludeContracts)

                    return .just(.init(hasError: result.error != nil, result: assetsExcluding))
                }
            }.eraseToAnyPublisher()
    }

    private struct NftAssetsFilter {
        let assets: [AlphaWallet.Address: [NftAsset]]

        func assets(excludeing excludeContracts: [(AlphaWallet.Address, RPCServer)]) -> [AlphaWallet.Address: [NftAsset]] {
            let excludeContracts = excludeContracts.map { $0.0 }
            return assets.filter { asset in !excludeContracts.contains(asset.key) }
        }
    }
}

//TODO extract to AlphaWalletCore or somewhere else
//TODO not threadsafe (is it necessary?). Be good if there's some library that does this better
fileprivate class CallCounter {
    //Just to be safe, not too big
    private static let maximumSize = 1000

    private static let windowInSeconds = 10

    private var calledAtTimes = [Int]()
    private var edge: Int {
        let currentTime = Int(Date().timeIntervalSince1970)
        return currentTime - Self.windowInSeconds
    }

    var averageRatePerSecond: Double {
        var total: Int = 0

        //TODO reversed might be much faster? But we are truncating already
        for each in calledAtTimes where each >= edge {
            total += 1
        }
        let result: Double = Double(total) / Double(Self.windowInSeconds)
        return result
    }

    func clock() {
        calledAtTimes.append(Int(Date().timeIntervalSince1970))
        if calledAtTimes.count > Self.maximumSize {
            if let i = calledAtTimes.firstIndex(where: { $0 >= edge }) {
                calledAtTimes = Array(calledAtTimes.dropFirst(i))
            }
        }
    }
}

extension OpenSea {
    //Better to throw a request error rather than receiving incorrect data
    enum OpenSeaRequestError: Error {
        case chainNotSupported
    }
    enum ApiVersion: String {
        case v1
        case v2
    }

    private struct AssetRequest: Alamofire.URLRequestConvertible {
        let baseUrl: URL
        let apiKey: String
        let server: RPCServer
        let asset: String

        private func apiVersion(server: RPCServer) throws -> ApiVersion {
            switch server {
            case .main: return .v1
            case .polygon: return .v2
            case .arbitrum: return .v2
            case .avalanche: return .v2
            case .klaytnCypress: return .v2
            case .optimistic: return .v2
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        private func pathToPlatform(server: RPCServer) throws -> String {
            switch server {
            case .main: return "/asset/"
            case .polygon: return "/metadata/matic/"
            case .arbitrum: return "/metadata/arbitrum/"
            case .avalanche: return "/metadata/avalanche/"
            case .klaytnCypress: return "/metadata/klaytn/"
            case .optimistic: return "/metadata/optimism/"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/\(try apiVersion(server: server))\(try pathToPlatform(server: server))\(asset)"

            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]

            return request
        }
    }

    private struct CollectionStatsRequest: Alamofire.URLRequestConvertible {
        let baseUrl: URL
        let apiKey: String
        let collectionId: String

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v1/collection/\(collectionId)/stats"

            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]

            return request
        }
    }

    private struct CollectionsRequest: Alamofire.URLRequestConvertible {
        let baseUrl: URL
        let apiKey: String
        let server: RPCServer
        let limit: Int = 300
        let offset: Int
        let owner: AlphaWallet.Address

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v1/collections"

            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]

            return try URLEncoding().encode(request, with: [
                "asset_owner": owner.eip55String,
                "limit": String(limit),
                "offset": String(offset)
            ])
        }
    }

    private struct AssetsRequest: Alamofire.URLRequestConvertible {
        let baseUrl: URL
        let owner: AlphaWallet.Address
        let orderBy: String = "pk"
        let orderDirection: String = "asc"
        let limit: Int = 50
        let apiKey: String
        let server: RPCServer

        private func apiVersion(server: RPCServer) throws -> ApiVersion {
            switch server {
            case .main: return .v1
            case .polygon: return .v2
            case .arbitrum: return .v2
            case .avalanche: return .v2
            case .klaytnCypress: return .v2
            case .optimistic: return .v2
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        private func pathToPlatform(server: RPCServer) throws -> String {
            switch server {
            case .main: return ""
            case .polygon: return "matic"
            case .arbitrum: return "arbitrum"
            case .avalanche: return "avalanche"
            case .klaytnCypress: return "klaytn"
            case .optimistic: return "optimism"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        private func ownerParamKey(server: RPCServer) throws -> String {
            switch server {
            case .main: return "owner"
            case .polygon: return "owner_address"
            case .arbitrum: return "owner_address"
            case .avalanche: return "owner_address"
            case .klaytnCypress: return "owner_address"
            case .optimistic: return "owner_address"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/\(try apiVersion(server: server))/assets/\(try pathToPlatform(server: server))"

            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]

            return try URLEncoding().encode(request, with: [
                ownerParamKey(server: server): owner.eip55String,
                "order_by": orderBy,
                "order_direction": orderDirection,
                "limit": String(limit)
            ])
        }
    }

    private struct AssetsCursorRequest: Alamofire.URLRequestConvertible {
        let apiKey: String
        let cursorUrl: String

        func asURLRequest() throws -> URLRequest {
            guard let url = URL(string: cursorUrl) else { throw URLError(.badURL) }
            var request = try URLRequest(url: url, method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]
            return request
        }
    }
}
