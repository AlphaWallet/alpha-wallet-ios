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

public typealias ChainId = Int
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

extension URLRequest {
    public typealias Response = (data: Data, response: HTTPURLResponse)
}

public typealias Request = Alamofire.URLRequestConvertible

public protocol Networking {
    func send(request: Request) -> AnyPublisher<URLRequest.Response, PromiseError>
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
}

public protocol OpenSeaNetworkingFactory {
    func networking(for chainId: ChainId) -> Networking
}

public final class BaseOpenSeaNetworkingFactory: OpenSeaNetworkingFactory {
    private var networkings: [URL: Networking] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.atomicDictionary", qos: .background)

    public static let shared = BaseOpenSeaNetworkingFactory()
    private init() { }

    public func networking(for chainId: ChainId) -> Networking {
        var networking: Networking!

        dispatchPrecondition(condition: .notOnQueue(queue))
        queue.sync { [unowned self] in
            let baseUrl = OpenSea.getBaseUrlForOpenSea(forChainId: chainId)
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
    private let apiKeys: [ChainId: String]

    weak public var delegate: OpenSeaDelegate?

    public init(apiKeys: [ChainId: String], networking: OpenSeaNetworkingFactory = BaseOpenSeaNetworkingFactory.shared) {
        self.apiKeys = apiKeys
        self.networking = networking
    }

    public func fetchAssetsCollections(owner: AlphaWallet.Address,
                                       chainId: ChainId,
                                       excludeContracts: [(AlphaWallet.Address, ChainId)]) -> AnyPublisher<Response<OpenSeaAddressesToNonFungibles>, Never> {

        //NOTE: some of OpenSea collections have an empty `primary_asset_contracts` array, so we are not able to identifyto each asset connection relates. it solves with `slug` field for collection. We match assets `slug` with collections `slug` values for identification
        func findCollection(address: AlphaWallet.Address, asset: NftAsset, collections: [CollectionKey: AlphaWalletOpenSea.NftCollection]) -> AlphaWalletOpenSea.NftCollection? {
            return collections[.address(address)] ?? collections[.collectionId(asset.collectionId)]
        }

        //NOTE: Due to OpenSea's policy of sending requests, (we are not able to sent multiple requests, the request trottled, and 1 sec delay is needed)
        //to send a new one. First we send fetch assets requests and then fetch collections requests

        let assets = fetchAssets(owner: owner, chainId: chainId, excludeContracts: excludeContracts)
        let collections = fetchCollections(owner: owner, chainId: chainId)

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

    static func getBaseUrlForOpenSea(forChainId chainId: ChainId) -> URL {
        switch chainId {
        case 1:
            return URL(string: "https://api.opensea.io")!
        case 4:
            return URL(string: "https://rinkeby-api.opensea.io")!
        default:
            return URL(string: "https://api.opensea.io")!
        }
    }

    private func openSeaKey(forChainId chainId: ChainId) -> String? {
        return apiKeys[chainId]
    }

    public func fetchAsset(asset: String,
                           chainId: ChainId) -> AnyPublisher<NftAsset, PromiseError> {
        
        let request = AssetRequest(
            baseUrl: Self.getBaseUrlForOpenSea(forChainId: chainId),
            apiKey: openSeaKey(forChainId: chainId) ?? "",
            chainId: chainId,
            asset: asset)

        return send(request: request, chainId: chainId)
            .mapError { PromiseError(error: $0) }
            .flatMap { json -> AnyPublisher<NftAsset, PromiseError> in
                if let asset = NftAsset(json: json) {
                    return .just(asset)
                } else {
                    return .fail(PromiseError(error: OpenSeaApiError.invalidJson))
                }
            }.eraseToAnyPublisher()
    }

    public func collectionStats(collectionId: String,
                                chainId: ChainId) -> AnyPublisher<NftCollectionStats, PromiseError> {

        let request = CollectionStatsRequest(
            baseUrl: Self.getBaseUrlForOpenSea(forChainId: chainId),
            apiKey: openSeaKey(forChainId: chainId) ?? "",
            collectionId: collectionId)

        return send(request: request, chainId: chainId)
            .mapError { PromiseError(error: $0) }
            .flatMap { json -> AnyPublisher<NftCollectionStats, PromiseError> in
                if json["stats"] != .null {
                    return .just(NftCollectionStats(json: json["stats"]))
                } else {
                    return .fail(PromiseError(error: OpenSeaApiError.invalidJson))
                }
            }.eraseToAnyPublisher()
    }

    private func fetchCollections(owner: AlphaWallet.Address,
                                  chainId: ChainId,
                                  offset: Int = 0,
                                  collections: [CollectionKey: NftCollection] = [:]) -> AnyPublisher<Response<[CollectionKey: NftCollection]>, Never> {

        let request = CollectionsRequest(
            baseUrl: Self.getBaseUrlForOpenSea(forChainId: chainId),
            apiKey: openSeaKey(forChainId: chainId) ?? "",
            chainId: chainId,
            offset: offset,
            owner: owner)

        let decoder = OpenSeaCollectionDecoder(collections: collections)

        return send(request: request, chainId: chainId)
            .map { decoder.decode(json: $0) }
            .catch { error -> AnyPublisher<NftCollectionsPage, Never> in
                return .just(.init(collections: [:], count: 0, hasNextPage: false, error: error))
            }.flatMap { [weak self] result -> AnyPublisher<Response<[CollectionKey: NftCollection]>, Never> in
                guard let strongSelf = self else { return .empty() }

                if result.hasNextPage {
                    return strongSelf.fetchCollections(owner: owner, chainId: chainId, offset: offset + result.count, collections: result.collections)
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

    private func send(request: Alamofire.URLRequestConvertible, chainId: ChainId) -> AnyPublisher<JSON, OpenSeaApiError> {
        networking.networking(for: chainId)
            .send(request: request)
            .tryMap { try JsonDecoder().decode(data: $0) }
            .mapError { OpenSeaApiError(error: $0) }
            .eraseToAnyPublisher()
    }

    private func fetchAssets(owner: AlphaWallet.Address,
                             chainId: ChainId,
                             next: String? = nil,
                             assets: OpenSeaAddressesToNonFungibles = [:],
                             excludeContracts: [(AlphaWallet.Address, ChainId)]) -> AnyPublisher<Response<OpenSeaAddressesToNonFungibles>, Never> {

        let request: Alamofire.URLRequestConvertible
        if let cursorUrl = next {
            request = AssetsCursorRequest(
                apiKey: openSeaKey(forChainId: chainId) ?? "",
                cursorUrl: cursorUrl)
        } else {
            request = AssetsRequest(
                baseUrl: Self.getBaseUrlForOpenSea(forChainId: chainId),
                owner: owner,
                apiKey: openSeaKey(forChainId: chainId) ?? "",
                chainId: chainId)
        }

        let decoder = NftAssetsPageDecoder(assets: assets)

        return send(request: request, chainId: chainId)
            .map { decoder.decode(json: $0) }
            .catch { error -> AnyPublisher<NftAssetsPage, Never> in
                let assetsExcluding = NftAssetsFilter(assets: assets).assets(excludeing: excludeContracts)
                return .just(.init(assets: assetsExcluding, count: 0, next: nil, error: error))
            }.flatMap { [weak self] result -> AnyPublisher<Response<OpenSeaAddressesToNonFungibles>, Never> in
                guard let strongSelf = self else { return .empty() }

                if let next = result.next {
                    return strongSelf.fetchAssets(
                        owner: owner,
                        chainId: chainId,
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

        func assets(excludeing excludeContracts: [(AlphaWallet.Address, ChainId)]) -> [AlphaWallet.Address: [NftAsset]] {
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
        let chainId: ChainId
        let asset: String

        private func apiVersion(chainId: ChainId) throws -> ApiVersion {
            switch chainId {
            case 1, 4: return .v1
            case 137: return .v2
            case 42161: return .v2
            case 0xa86a: return .v2
            case 8217: return .v2
            case 10: return .v2
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        private func pathToPlatform(chainId: ChainId) throws -> String {
            switch chainId {
            case 1, 4: return "/asset/"
            case 137: return "/metadata/matic/"
            case 42161: return "/metadata/arbitrum/"
            case 0xa86a: return "/metadata/avalanche/"
            case 8217: return "/metadata/klaytn/"
            case 10: return "/metadata/optimism/"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/\(try apiVersion(chainId: chainId))\(try pathToPlatform(chainId: chainId))\(asset)"

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
        let chainId: ChainId
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
        let chainId: ChainId

        private func apiVersion(chainId: ChainId) throws -> ApiVersion {
            switch chainId {
            case 1, 4: return .v1
            case 137: return .v2
            case 42161: return .v2
            case 0xa86a: return .v2
            case 8217: return .v2
            case 10: return .v2
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        private func pathToPlatform(chainId: ChainId) throws -> String {
            switch chainId {
            case 1, 4: return ""
            case 137: return "matic"
            case 42161: return "arbitrum"
            case 0xa86a: return "avalanche"
            case 8217: return "klaytn"
            case 10: return "optimism"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        private func ownerParamKey(chainId: ChainId) throws -> String {
            switch chainId {
            case 1, 4: return "owner"
            case 137: return "owner_address"
            case 42161: return "owner_address"
            case 0xa86a: return "owner_address"
            case 8217: return "owner_address"
            case 10: return "owner_address"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/\(try apiVersion(chainId: chainId))/assets/\(try pathToPlatform(chainId: chainId))"

            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]

            return try URLEncoding().encode(request, with: [
                ownerParamKey(chainId: chainId): owner.eip55String,
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
