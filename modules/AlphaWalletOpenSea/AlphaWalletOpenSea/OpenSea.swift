//
//  OpenSea.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/29/22.
//

import AlphaWalletAddress
import AlphaWalletCore
import PromiseKit
import SwiftyJSON
import Alamofire

public typealias ChainId = Int
public typealias OpenSeaAddressesToNonFungibles = [AlphaWallet.Address: [NftAsset]]

public protocol OpenSeaDelegate: AnyObject {
    func openSeaError(error: OpenSeaApiError)
}

public enum OpenSeaApiError: Error {
    case rateLimited
    case invalidApiKey
    case expiredApiKey
}

public class OpenSea {
    public static var isLoggingEnabled = false
    //Important to be static so it's for *all* OpenSea calls
    private static let callCounter = CallCounter()

    private let sessionManagerWithDefaultHttpHeaders: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30

        return Session(configuration: configuration)
    }()

    private let apiKeys: [ChainId: String]

    weak public var delegate: OpenSeaDelegate?

    public init(apiKeys: [ChainId: String]) {
        self.apiKeys = apiKeys
    }

    public func fetchAssetsPromise(address owner: AlphaWallet.Address, chainId: ChainId, excludeContracts: [(AlphaWallet.Address, ChainId)]) -> Promise<Response<OpenSeaAddressesToNonFungibles>> {
        let offset = 0
        //NOTE: some of OpenSea collections have an empty `primary_asset_contracts` array, so we are not able to identifyto each asset connection relates. it solves with `slug` field for collection. We match assets `slug` with collections `slug` values for identification
        func findCollection(address: AlphaWallet.Address, asset: NftAsset, collections: [CollectionKey: AlphaWalletOpenSea.NftCollection]) -> AlphaWalletOpenSea.NftCollection? {
            return collections[.address(address)] ?? collections[.collectionId(asset.collectionId)]
        }

        //NOTE: Due to OpenSea's policy of sending requests, (we are not able to sent multiple requests, the request trottled, and 1 sec delay is needed)
        //to send a new one. First we send fetch assets requests and then fetch collections requests
        typealias OpenSeaAssetsAndCollections = (OpenSeaAddressesToNonFungibles, [CollectionKey: AlphaWalletOpenSea.NftCollection])

        let assetsPromise = fetchAssets(owner: owner, chainId: chainId, excludeContracts: excludeContracts)
        let collectionsPromise = fetchCollectionsPage(forOwner: owner, chainId: chainId, offset: offset)

        return when(resolved: [assetsPromise.asVoid(), collectionsPromise.asVoid()])
            .map(on: .global(), { _ -> Response<OpenSeaAddressesToNonFungibles> in
                let assets = assetsPromise.result?.optionalValue ?? .init(hasError: true, result: [:])
                let collections = collectionsPromise.result?.optionalValue ?? .init(hasError: true, result: [:])

                var result: [AlphaWallet.Address: [NftAsset]] = [:]
                for each in assets.result {
                    let updatedElements = each.value.map { openSeaNonFungible -> NftAsset in
                        var openSeaNonFungible = openSeaNonFungible
                        let collection = findCollection(address: each.key, asset: openSeaNonFungible, collections: collections.result)
                        openSeaNonFungible.collection = collection

                        return openSeaNonFungible
                    }

                    result[each.key] = updatedElements
                }
                let hasError = assets.hasError || collections.hasError

                return .init(hasError: hasError, result: result)
            }).recover({ _ -> Promise<Response<OpenSeaAddressesToNonFungibles>> in
                return .value(.init(hasError: true, result: [:]))
            })
    }

    private func getBaseUrlForOpenSea(forChainId chainId: ChainId) -> URL {
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

    public func fetchAssetImageUrl(asset: String, chainId: ChainId) -> Promise<URL> {
        let request = AssetRequest(
            baseUrl: getBaseUrlForOpenSea(forChainId: chainId),
            apiKey: openSeaKey(forChainId: chainId) ?? "",
            chainId: chainId,
            asset: asset)

        return firstly {
            performRequestWithRetry(request: request, queue: .main)
        }.map { json -> URL in
            let image: String = json["image_url"].string ?? json["image_preview_url"].string ?? json["image_thumbnail_url"].string ?? json["image_original_url"].string ?? ""
            guard let url = URL(string: image) else {
                throw OpenSeaError(localizedDescription: "Error calling \(self.getBaseUrlForOpenSea(forChainId: chainId))")
            }
            return url
        }
    }

    public func collectionStats(slug: String, chainId: ChainId) -> Promise<NftCollectionStats> {
        let request = CollectionStatsRequest(
            baseUrl: getBaseUrlForOpenSea(forChainId: chainId),
            apiKey: openSeaKey(forChainId: chainId) ?? "",
            slug: slug)

        //TODO Why is specifying .main queue needed?
        return firstly {
            performRequestWithRetry(request: request, queue: .main)
        }.map { json -> NftCollectionStats in
            try NftCollectionStats(json: json)
        }
    }

    private func fetchCollectionsPage(forOwner owner: AlphaWallet.Address, chainId: ChainId, offset: Int, collections: [CollectionKey: NftCollection] = [:]) -> Promise<Response<[CollectionKey: NftCollection]>> {
        let request = CollectionsRequest(
            baseUrl: getBaseUrlForOpenSea(forChainId: chainId),
            apiKey: openSeaKey(forChainId: chainId) ?? "",
            chainId: chainId,
            offset: offset,
            owner: owner)

        let decoder = OpenSeaCollectionDecoder(collections: collections)
        return firstly {
            performRequestWithRetry(request: request, queue: .global())
        }.then(on: .global(), { [weak self] json -> Promise<Response<[CollectionKey: NftCollection]>> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }
            let result = decoder.decode(json: json)
            if result.hasNextPage {
                return strongSelf.fetchCollectionsPage(forOwner: owner, chainId: chainId, offset: offset + result.count, collections: result.collections)
            } else {
                return .value(.init(hasError: false, result: result.collections))
            }
        }).recover { _ -> Promise<Response<[CollectionKey: NftCollection]>> in
            //NOTE: return some already fetched amount
            return .value(.init(hasError: true, result: collections))
        }
    }

    private func performRequestWithRetry(request: Alamofire.URLRequestConvertible, maximumRetryCount: Int = 3, delayMultiplayer: Int = 5, retryDelay: DispatchTimeInterval = .seconds(2), queue: DispatchQueue) -> Promise<JSON> {
        func privatePerformRequest(request: Alamofire.URLRequestConvertible) -> Promise<JSON> {
            //Using responseData() instead of responseJSON() below because `PromiseKit`'s `responseJSON()` resolves to failure if body isn't JSON. But OpenSea returns a non-JSON when the status code is 401 (unauthorized, aka. wrong API key) and we want to detect that.
            return sessionManagerWithDefaultHttpHeaders
                    .request(request)
                    .publishData(queue: queue)
                    .eraseToAnyPublisher()
                    .promise()
                    .map(on: queue, { response -> JSON in
                        if let data = response.data, let response = response.response {
                            if response.statusCode == 401 {
                                if let body = String(data: data, encoding: .utf8), body.contains("Expired API key") {
                                    throw OpenSeaApiError.expiredApiKey
                                } else {
                                    throw OpenSeaApiError.invalidApiKey
                                }
                            } else if response.statusCode == 429 {
                                throw OpenSeaApiError.rateLimited
                            }
                            if let json = try? JSON(data: data) {
                                return json
                            } else {
                                throw OpenSeaError(localizedDescription: "Error calling \(try? request.asURLRequest().url?.absoluteString)")
                            }
                        } else {
                            throw OpenSeaError(localizedDescription: "Error calling \(try? request.asURLRequest().url?.absoluteString)")
                        }
                    }).recover { error -> Promise<JSON> in
                        if let error = error as? OpenSeaApiError {
                            self.delegate?.openSeaError(error: error)
                        } else {
                            //no-op
                        }
                        throw error
                    }
        }

        let delayUpperRangeValueFrom0To: Int = delayMultiplayer
        return firstly {
            attempt(maximumRetryCount: maximumRetryCount, delayBeforeRetry: retryDelay, delayUpperRangeValueFrom0To: delayUpperRangeValueFrom0To) {
                DispatchQueue.main.async {
                    Self.callCounter.clock()
                    infoLog("[OpenSea] Accessing url: \(try? request.asURLRequest().url?.absoluteString) rate: \(Self.callCounter.averageRatePerSecond)/sec")
                }
                return privatePerformRequest(request: request)
            }
        }.recover { error -> Promise<JSON> in
            infoLog("[OpenSea] API error: \(error)")
            throw error
        }
    }

    private func fetchAssets(owner: AlphaWallet.Address,
                             chainId: ChainId,
                             next: String? = nil,
                             assets: OpenSeaAddressesToNonFungibles = [:],
                             excludeContracts: [(AlphaWallet.Address, ChainId)]) -> Promise<Response<OpenSeaAddressesToNonFungibles>> {

        let request: Alamofire.URLRequestConvertible
        if let cursorUrl = next {
            request = AssetsCursorRequest(
                apiKey: openSeaKey(forChainId: chainId) ?? "",
                cursorUrl: cursorUrl)
        } else {
            request = AssetsRequest(
                baseUrl: getBaseUrlForOpenSea(forChainId: chainId),
                owner: owner,
                apiKey: openSeaKey(forChainId: chainId) ?? "",
                chainId: chainId)
        }

        let decoder = NftAssetsPageDecoder(assets: assets)
        return firstly {
            performRequestWithRetry(request: request, queue: .global())
        }.then({ [weak self] json -> Promise<Response<OpenSeaAddressesToNonFungibles>> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }
            let result = decoder.decode(json: json)

            if let next = result.next {
                return strongSelf.fetchAssets(
                    owner: owner,
                    chainId: chainId,
                    next: next,
                    assets: result.assets,
                    excludeContracts: excludeContracts)
            } else {
                let assetsExcluding = NftAssetsFilter(assets: result.assets).assets(excluding: excludeContracts)
                return .value(.init(hasError: false, result: assetsExcluding))
            }
        }).recover { _ -> Promise<Response<OpenSeaAddressesToNonFungibles>> in
            //NOTE: return some already fetched amount
            let assetsExcluding = NftAssetsFilter(assets: assets).assets(excluding: excludeContracts)
            return .value(.init(hasError: true, result: assetsExcluding))
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
        let slug: String

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v1/collection/\(slug)/stats"

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

import Combine

extension AnyPublisher {
    fileprivate func promise() -> Promise<Output> {
        var cancellable: AnyCancellable?
        return Promise<Output> { seal in
            cancellable = self
                .receive(on: RunLoop.main)
                .sink { result in
                    if case .failure(let error) = result {
                        seal.reject(error)
                    }
                    cancellable = nil
                } receiveValue: {
                    seal.fulfill($0)
                }
        }
    }
}
