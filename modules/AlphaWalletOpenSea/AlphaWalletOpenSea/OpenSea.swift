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

public typealias ChainId = Int
public typealias OpenSeaAddressesToNonFungibles = [AlphaWallet.Address: [OpenSeaNonFungible]]

public protocol OpenSeaDelegate: class {
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

    //TODO why is this needed? Make it always respond on main instead
    private let queue: DispatchQueue

    private let sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30

        return SessionManager(configuration: configuration)
    }()

    private var apiKeys: [ChainId: String]

    weak public var delegate: OpenSeaDelegate?

    public init(apiKeys: [ChainId: String], queue: DispatchQueue) {
        self.apiKeys = apiKeys
        self.queue = queue
    }

    public func fetchAssetsPromise(address owner: AlphaWallet.Address, chainId: ChainId, excludeContracts: [(AlphaWallet.Address, ChainId)]) -> Promise<Response<OpenSeaAddressesToNonFungibles>> {
        let offset = 0
        //NOTE: some of OpenSea collections have an empty `primary_asset_contracts` array, so we are not able to identifyto each asset connection relates. it solves with `slug` field for collection. We match assets `slug` with collections `slug` values for identification
        func findCollection(address: AlphaWallet.Address, asset: OpenSeaNonFungible, collections: [CollectionKey: AlphaWalletOpenSea.Collection]) -> AlphaWalletOpenSea.Collection? {
            return collections[.address(address)] ?? collections[.slug(asset.slug)]
        }

        //NOTE: Due to OpenSea's policy of sending requests, (we are not able to sent multiple requests, the request trottled, and 1 sec delay is needed)
        //to send a new one. First we send fetch assets requests and then fetch collections requests
        typealias OpenSeaAssetsAndCollections = (OpenSeaAddressesToNonFungibles, [CollectionKey: AlphaWalletOpenSea.Collection])

        let assetsPromise = fetchAssetsPage(forOwner: owner, chainId: chainId, offset: offset, excludeContracts: excludeContracts)
        let collectionsPromise = fetchCollectionsPage(forOwner: owner, chainId: chainId, offset: offset)

        return when(resolved: [assetsPromise.asVoid(), collectionsPromise.asVoid()])
                .map(on: queue, { _ -> Response<OpenSeaAddressesToNonFungibles> in
                    let assets = assetsPromise.result?.optionalValue ?? .init(hasError: true, result: [:])
                    let collections = collectionsPromise.result?.optionalValue ?? .init(hasError: true, result: [:])

                    var result: [AlphaWallet.Address: [OpenSeaNonFungible]] = [:]
                    for each in assets.result {
                        let updatedElements = each.value.map { openSeaNonFungible -> OpenSeaNonFungible in
                            var openSeaNonFungible = openSeaNonFungible
                            let collection = findCollection(address: each.key, asset: openSeaNonFungible, collections: collections.result)
                            openSeaNonFungible.collection = collection

                            return openSeaNonFungible
                        }

                        result[each.key] = updatedElements
                    }
                    let hasError = assets.hasError || collections.hasError

                    return .init(hasError: hasError, result: result)
                })
                .recover({ _ -> Promise<Response<OpenSeaAddressesToNonFungibles>> in
                    return .value(.init(hasError: true, result: [:]))
                })
    }

    private func getBaseURLForOpenSea(forChainId chainId: ChainId) -> String {
        switch chainId {
        case 1:
            return "https://api.opensea.io/"
        case 4:
            return "https://rinkeby-api.opensea.io/"
        default:
            return "https://api.opensea.io/"
        }
    }

    private func openSeaKey(forChainId chainId: ChainId) -> String? {
        return apiKeys[chainId]
    }

    public func fetchAssetImageUrl(path: String, chainId: ChainId) -> Promise<URL> {
        let baseURL = getBaseURLForOpenSea(forChainId: chainId)
        guard let url = URL(string: "\(baseURL)api/v1/asset/\(path)") else {
            return .init(error: OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)"))
        }

        return firstly {
            performRequestWithRetry(chainId: chainId, url: url, queue: .main)
        }.map { json -> URL in
            let image: String = json["image_url"].string ?? json["image_preview_url"].string ?? json["image_thumbnail_url"].string ?? json["image_original_url"].string ?? ""
            guard let url = URL(string: image) else {
                throw OpenSeaError(localizedDescription: "Error calling \(baseURL)")
            }
            return url
        }
    }

    public func collectionStats(slug: String, chainId: ChainId) -> Promise<Stats> {
        let baseURL = getBaseURLForOpenSea(forChainId: chainId)
        guard let url = URL(string: "\(baseURL)api/v1/collection/\(slug)/stats") else {
            return .init(error: OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)"))
        }

        //TODO Why is specifying .main queue needed?
        return firstly {
            performRequestWithRetry(chainId: chainId, url: url, queue: .main)
        }.map { json -> Stats in
            try Stats(json: json)
        }
    }

    private func fetchCollectionsPage(forOwner owner: AlphaWallet.Address, chainId: ChainId, offset: Int, sum: [CollectionKey: Collection] = [:]) -> Promise<Response<[CollectionKey: Collection]>> {
        let baseURL = getBaseURLForOpenSea(forChainId: chainId)
        guard let url = URL(string: "\(baseURL)api/v1/collections?asset_owner=\(owner.eip55String)&limit=300&offset=\(offset)") else {
            return .init(error: OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)"))
        }

        return firstly {
            performRequestWithRetry(chainId: chainId, url: url, queue: queue)
        }.then(on: queue, { [weak self] json -> Promise<Response<[CollectionKey: Collection]>> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }
            let results = OpenSeaCollectionDecoder.decode(json: json, results: sum)
            let fetchedCount = json.arrayValue.count
            if fetchedCount > 0 {
                return strongSelf.fetchCollectionsPage(forOwner: owner, chainId: chainId, offset: offset + fetchedCount, sum: results)
            } else {
                return .value(.init(hasError: false, result: sum))
            }
        }).recover { _ -> Promise<Response<[CollectionKey: Collection]>> in
            //NOTE: return some already fetched amount
            return .value(.init(hasError: true, result: sum))
        }
    }

    private func performRequestWithRetry(chainId: ChainId, url: URL, maximumRetryCount: Int = 3, delayMultiplayer: Int = 5, retryDelay: DispatchTimeInterval = .seconds(2), queue: DispatchQueue) -> Promise<JSON> {
        func privatePerformRequest(url: URL) -> Promise<(HTTPURLResponse, JSON)> {
            var headers: [String: String] = .init()
            headers["X-API-KEY"] = openSeaKey(forChainId: chainId)
            //Using responseData() instead of responseJSON() below because `PromiseKit`'s `responseJSON()` resolves to failure if body isn't JSON. But OpenSea returns a non-JSON when the status code is 401 (unauthorized, aka. wrong API key) and we want to detect that.
            return sessionManagerWithDefaultHttpHeaders
                    .request(url, method: .get, headers: headers)
                    .responseData()
                    .map(on: queue, { data, response -> (HTTPURLResponse, JSON) in
                        if let response: HTTPURLResponse = response.response {
                            let statusCode = response.statusCode
                            if statusCode == 401 {
                                if let body = String(data: data, encoding: .utf8), body.contains("Expired API key") {
                                    throw OpenSeaApiError.expiredApiKey
                                } else {
                                    throw OpenSeaApiError.invalidApiKey
                                }
                            } else if statusCode == 429 {
                                throw OpenSeaApiError.rateLimited
                            }
                            if let json = try? JSON(data: data) {
                                return (response, json)
                            } else {
                                throw OpenSeaError(localizedDescription: "Error calling \(url)")
                            }
                        } else {
                            throw OpenSeaError(localizedDescription: "Error calling \(url)")
                        }
                    }).recover { error -> Promise<(HTTPURLResponse, JSON)> in
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
                    infoLog("[OpenSea] Accessing url: \(url.absoluteString) rate: \(Self.callCounter.averageRatePerSecond)/sec")
                }
                return firstly {
                    privatePerformRequest(url: url)
                }.map { _, json -> JSON in
                    json
                }
            }
        }.recover { error -> Promise<JSON> in
            infoLog("[OpenSea] API error: \(error)")
            throw error
        }
    }

    private func fetchAssetsPage(forOwner owner: AlphaWallet.Address, chainId: ChainId, offset: Int, assets: OpenSeaAddressesToNonFungibles = [:], excludeContracts: [(AlphaWallet.Address, ChainId)]) -> Promise<Response<OpenSeaAddressesToNonFungibles>> {
        let baseURL = getBaseURLForOpenSea(forChainId: chainId)
        //Careful to `order_by` with a valid value otherwise OpenSea will return 0 results
        guard let url = URL(string: "\(baseURL)api/v1/assets/?owner=\(owner.eip55String)&order_by=pk&order_direction=asc&limit=50&offset=\(offset)") else {
            return .init(error: OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)"))
        }

        return firstly {
            performRequestWithRetry(chainId: chainId, url: url, queue: queue)
        }.then({ [weak self] json -> Promise<Response<OpenSeaAddressesToNonFungibles>> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }
            let results = OpenSeaAssetDecoder.decode(json: json, assets: assets)
            let fetchedCount = json["assets"].count
            if fetchedCount > 0 {
                return strongSelf.fetchAssetsPage(forOwner: owner, chainId: chainId, offset: offset + fetchedCount, assets: results, excludeContracts: excludeContracts)
            } else {
                let excludeContracts = excludeContracts.map { $0.0 }
                let assetsExcluding = assets.filter { eachAsset in
                    !excludeContracts.contains { $0.sameContract(as: eachAsset.key) }
                }
                return .value(.init(hasError: false, result: assetsExcluding))
            }
        }).recover { _ -> Promise<Response<OpenSeaAddressesToNonFungibles>> in
            //NOTE: return some already fetched amount
            let excludeContracts = excludeContracts.map { $0.0 }
            let assetsExcluding = assets.filter { eachAsset in
                !excludeContracts.contains { $0.sameContract(as: eachAsset.key) }
            }
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
