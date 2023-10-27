//
//  OpenSea.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/29/22.
//

import Combine
import AlphaWalletAddress
import AlphaWalletCore
import Alamofire
import BigInt
import SwiftyJSON

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
    func networking(for server: RPCServer) async -> Networking
}

public final actor BaseOpenSeaNetworkingFactory: OpenSeaNetworkingFactory {
    private var networkings: [URL: Networking] = [:]

    public static let shared = BaseOpenSeaNetworkingFactory()
    private init() { }

    public func networking(for server: RPCServer) async -> Networking {
        var networking: Networking!
        let baseUrl = OpenSea.getBaseUrlForOpenSea(forServer: server)
        if let _networking = self.networkings[baseUrl] {
            networking = _networking
        } else {
            networking = OpenSeaNetworking()
            self.networkings[baseUrl] = networking
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
        let assets = fetchAssets(owner: owner, server: server, excludeContracts: excludeContracts)
        return assets
            .flatMap { assets in
                let collectionIds: [String] = assets.result.values.flatMap { $0.map { $0.collectionId } }
                let collections = self.fetchCollections(collectionIds: collectionIds, server: server)
                return Publishers.CombineLatest(Just<Response<OpenSeaAddressesToNonFungibles>>(assets), collections).eraseToAnyPublisher()
            }.map { assets, collections in
                var result: [AlphaWallet.Address: [NftAsset]] = functional.combineCollectionsWithAssets(allNfts: assets.result, collections: collections.result)
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

    public func fetchAsset(contract: AlphaWallet.Address, id: BigUInt, server: RPCServer) async throws -> NftAsset {
        let request = AssetRequest(baseUrl: Self.getBaseUrlForOpenSea(forServer: server), apiKey: openSeaKey(forServer: server) ?? "", server: server, contract: contract, id: id)
        let json = try await sendAsync(request: request, server: server)
        if let asset = NftAsset(json: json["nft"]) {
            return asset
        } else {
            throw OpenSeaApiError.invalidJson
        }
    }

    public func collectionStats(collectionId: String, server: RPCServer) -> AnyPublisher<NftCollectionStats, PromiseError> {
        let request = CollectionStatsRequest(baseUrl: Self.getBaseUrlForOpenSea(forServer: server), apiKey: openSeaKey(forServer: server) ?? "", collectionId: collectionId)
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

    //TODO skip those that we already have?
    private func fetchCollections(collectionIds: [String], server: RPCServer, offset: Int = 0) -> AnyPublisher<Response<[CollectionKey: NftCollection]>, Never> {
        //Important to make unique here otherwise we would crash later with `Dictionary(uniqueKeysWithValues:)`
        let collectionIds = Set(collectionIds)
        let requests = collectionIds
            .map { CollectionRequest(baseUrl: Self.getBaseUrlForOpenSea(forServer: server), apiKey: openSeaKey(forServer: server) ?? "", server: server, collectionSlug: $0) }
            //Delay to avoid hitting OpenSea rate limits We do a delay after the request instead of before to keep the code shorter, it doesn't really matter
            .map { send(request: $0, server: server).delay(for: .milliseconds(500), scheduler: DispatchQueue.main) }
        return Publishers.MergeMany(requests)
            .map { NftCollection(json: $0) }
            .mapToResult()
            .collect()
            .map { $0.compactMap { try? $0.get() } }
            .flatMap { collections -> AnyPublisher<Response<[CollectionKey: NftCollection]>, Never> in
                let result = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0) })
                return Just(Response(hasError: false, result: result)).eraseToAnyPublisher()
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
        return asFutureThrowable {
            try await self.sendAsync(request: request, server: server)
        }.mapError { OpenSeaApiError(error: $0) }
        .eraseToAnyPublisher()
    }

    private func sendAsync(request: Alamofire.URLRequestConvertible, server: RPCServer) async throws -> JSON {
        let response = try await networking.networking(for: server).sendAsync(request: request)
        do {
            return try JsonDecoder().decode(data: response)
        } catch let error as OpenSeaApiError {
            switch error {
            case .internal, .invalidJson, .rateLimited:
                break
            case .invalidApiKey, .expiredApiKey:
                infoLog("[OpenSea] API key error: \(error)")
            }
            throw error
        }
    }

    private func fetchAssets(owner: AlphaWallet.Address, server: RPCServer, next: String? = nil, assets: OpenSeaAddressesToNonFungibles = [:], excludeContracts: [(AlphaWallet.Address, RPCServer)]) -> AnyPublisher<Response<OpenSeaAddressesToNonFungibles>, Never> {
        let request: Alamofire.URLRequestConvertible
        request = AssetsRequest(baseUrl: Self.getBaseUrlForOpenSea(forServer: server), owner: owner, apiKey: openSeaKey(forServer: server) ?? "", server: server, next: next)
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

extension OpenSea {
    enum functional {}
}

fileprivate extension OpenSea.functional {
    static func combineCollectionsWithAssets(allNfts: OpenSeaAddressesToNonFungibles, collections: [CollectionKey: NftCollection]) -> OpenSeaAddressesToNonFungibles {
        var result: OpenSeaAddressesToNonFungibles = [:]
        for (key, assets) in allNfts {
            guard let anyInCollection = assets.first else { continue }
            guard var collection = collections[anyInCollection.collectionId] else { continue }
            collection.ownedAssetCount = assets.count
            let updated = assets.map { _asset -> NftAsset in
                var _asset = _asset
                _asset.collection = collection
                _asset.contractName = collection.name
                _asset.contractImageUrl = collection.imageUrl ?? _asset.contractImageUrl
                _asset.collectionDescription = collection.descriptionString
                return _asset
            }
            result[key] = updated
        }
        return result
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

    private struct AssetRequest: Alamofire.URLRequestConvertible {
        let baseUrl: URL
        let apiKey: String
        let server: RPCServer
        let contract: AlphaWallet.Address
        let id: BigUInt

        private func pathToPlatform(server: RPCServer) throws -> String {
            switch server {
            case .main: return "ethereum"
            case .polygon: return "matic"
            case .arbitrum: return "arbitrum"
            case .avalanche: return "avalanche"
            case .klaytnCypress: return "klaytn"
            case .optimistic: return "optimism"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            //Lowercase contract, just in case. Higher chance if it's case-sensitive that lowercase works than EIP-55
            components.path = "/api/v2/chain/\(try pathToPlatform(server: server))/contract/\(contract.eip55String.lowercased())/nfts/\(id)"
            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]

            return request
        }
    }

    //TODO there doesn't seem to be a OpenSea API v2 equivalent for this. But v1 still works as of 20231027. Check for v2 periodically
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

    private struct CollectionRequest: Alamofire.URLRequestConvertible {
        let baseUrl: URL
        let apiKey: String
        let server: RPCServer
        let collectionSlug: String

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v2/collections/\(collectionSlug)"
            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]
            return try URLEncoding().encode(request, with: nil)
        }
    }

    private struct AssetsRequest: Alamofire.URLRequestConvertible {
        let baseUrl: URL
        let owner: AlphaWallet.Address
        let limit: Int = 200
        let apiKey: String
        let server: RPCServer
        let next: String?

        private func pathToPlatform(server: RPCServer) throws -> String {
            switch server {
            case .main: return "ethereum"
            case .polygon: return "matic"
            case .arbitrum: return "arbitrum"
            case .avalanche: return "avalanche"
            case .klaytnCypress: return "klaytn"
            case .optimistic: return "optimism"
            default: throw OpenSeaRequestError.chainNotSupported
            }
        }

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v2/chain/\(try pathToPlatform(server: server))/account/\(owner.eip55String)/nfts"
            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = ["X-API-KEY": apiKey]
            var parameters: Parameters = [
                "limit": String(limit)
            ]
            if let next {
                parameters["next"] = next
            }
            return try URLEncoding().encode(request, with: parameters)
        }
    }
}
