// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import PromiseKit
import Result
import SwiftyJSON

typealias OpenSeaNonFungiblesToAddress = [AlphaWallet.Address: [OpenSeaNonFungible]]

class OpenSea {
    private static var statsCache: [String: OpenSea.Stats] = [:]
    //Assuming 1 token (token ID, rather than a token) is 4kb, 1500 HyperDragons is 6MB. So we rate limit requests
    private static let numberOfTokenIdsBeforeRateLimitingRequests = 25
    private static let minimumSecondsBetweenRequests = TimeInterval(60)
    private static var instances = [AddressAndRPCServer: WeakRef<OpenSea>]()
    //NOTE: using AddressAndRPCServer fixes issue with incorrect tokens returned from makeFetchPromise
    // the problem was that cached OpenSea returned tokens from multiple wallets
    private let key: AddressAndRPCServer

    private var recentWalletsWithManyTokens: [AlphaWallet.Address: (Date, Promise<OpenSeaNonFungiblesToAddress>)] = [:]
    private var fetch = OpenSea.makeEmptyFulfilledPromise()
    private let queue = DispatchQueue.global(qos: .userInitiated)
    private let keystore: Keystore

    private init(key: AddressAndRPCServer, keystore: Keystore) {
        self.key = key
        self.keystore = keystore
    }

    static func createInstance(with key: AddressAndRPCServer, keystore: Keystore) -> OpenSea {
        if let instance = instances[key]?.object {
            return instance
        } else {
            let instance = OpenSea(key: key, keystore: keystore)
            instances[key] = WeakRef(object: instance)
            return instance
        }
    }

    private static func makeEmptyFulfilledPromise() -> Promise<OpenSeaNonFungiblesToAddress> {
        return Promise {
            $0.fulfill([:])
        }
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main, .rinkeby:
            return true
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return false
        }
    }

    static func resetInstances() {
        for each in instances.values {
            each.object?.reset()
        }
    }

    ///Call this after switching wallets, otherwise when the current promise is fulfilled, the switched to wallet will think the API results are for them
    private func reset() {
        fetch = OpenSea.makeEmptyFulfilledPromise()
    }

    ///Uses a promise to make sure we don't fetch from OpenSea multiple times concurrently
    func makeFetchPromise() -> Promise<OpenSeaNonFungiblesToAddress> {
        let owner = key.address
        guard OpenSea.isServerSupported(key.server) else {
            fetch = .value([:])
            return fetch
        }

        trimCachedPromises()

        if let cachedPromise = cachedPromise(forOwner: owner) {
            return cachedPromise
        }

        let queue = queue
        if fetch.isResolved {
            let offset = 0
            //NOTE: some of OpenSea collections have an empty `primary_asset_contracts` array, so we are not able to identifyto each asset connection relates. it solves with `slug` field for collection. We match assets `slug` with collections `slug` values for identification
            func findCollection(address: AlphaWallet.Address, asset: OpenSeaNonFungible, collections: [OpenSea.CollectionKey: OpenSea.Collection]) -> OpenSea.Collection? {
                return collections[.address(address)] ?? collections[.slug(asset.slug)]
            }

            //NOTE: Due to OpenSea's policy of sending requests, (we are not able to sent multiple requests, the request trottled, and 1 sec delay is needed)
            //to send a new one. First we send fetch assets requests and then fetch collections requests
            typealias OpenSeaAssetsAndCollections = ([AlphaWallet.Address: [OpenSeaNonFungible]], [OpenSea.CollectionKey: OpenSea.Collection])

            fetch = firstly {
                fetchAssetsPage(forOwner: owner, offset: offset)
            }.then(on: queue, { assets -> Promise<OpenSeaAssetsAndCollections> in
                return self.fetchCollectionsPage(forOwner: owner, offset: offset)
                    .map({ collections -> OpenSeaAssetsAndCollections in
                        return (assets, collections)
                    })
            }).map(on: queue, { (assetsExcludingUefa, collections) -> [AlphaWallet.Address: [OpenSeaNonFungible]] in
                var result: [AlphaWallet.Address: [OpenSeaNonFungible]] = [:]
                for each in assetsExcludingUefa {
                    let updatedElements = each.value.map { openSeaNonFungible -> OpenSeaNonFungible in
                        var openSeaNonFungible = openSeaNonFungible
                        let collection = findCollection(address: each.key, asset: openSeaNonFungible, collections: collections)
                        openSeaNonFungible.collection = collection

                        return openSeaNonFungible
                    }

                    result[each.key] = updatedElements
                }

                //NOTE: Not sure if we still need this caching feature, as we retry each failured request
                var tokenIdCount = 0
                for (_, tokenIds) in assetsExcludingUefa {
                    tokenIdCount += tokenIds.count
                }
                self.cachePromise(withTokenIdCount: tokenIdCount, forOwner: owner)

                return result
            })
        }

        return fetch
    }

    private static func getBaseURLForOpensea(for server: RPCServer) -> String {
        switch server {
        case .main:
            return Constants.openseaAPI
        case .rinkeby:
            return Constants.openseaRinkebyAPI
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return Constants.openseaAPI
        }
    }

    static func fetchAssetImageUrl(for value: Eip155URL) -> Promise<URL> {
        let baseURL = getBaseURLForOpensea(for: .main)
        guard let url = URL(string: "\(baseURL)api/v1/asset/\(value.path)") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return OpenSea.performOpenSeaRequest(url: url, queue: .main).map { json -> URL in
            let image: String = json["image_url"].string ?? json["image_preview_url"].string ?? json["image_thumbnail_url"].string ?? json["image_original_url"].string ?? ""
            guard let url = URL(string: image) else {
                throw AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL)"))
            }
            return url
        }
    }

    private static let sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30

        return SessionManager(configuration: configuration)
    }()

    static func collectionStats(slug: String) -> Promise<Stats> {
        let baseURL = OpenSea.getBaseURLForOpensea(for: .main)
        guard let url = URL(string: "\(baseURL)api/v1/collection/\(slug)/stats") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return OpenSea.performOpenSeaRequest(url: url, queue: .main).map { json -> Stats in
            return try Stats(json: json)
        }
    }

    private func fetchCollectionsPage(forOwner owner: AlphaWallet.Address, offset: Int, sum: [OpenSea.CollectionKey: OpenSea.Collection] = [:]) -> Promise<[OpenSea.CollectionKey: OpenSea.Collection]> {
        let baseURL = OpenSea.getBaseURLForOpensea(for: key.server)
        guard let url = URL(string: "\(baseURL)api/v1/collections?asset_owner=\(owner.eip55String)&limit=300&offset=\(offset)") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return OpenSea.performOpenSeaRequest(url: url, queue: queue)
            .then({ [weak self] json -> Promise<[OpenSea.CollectionKey: OpenSea.Collection]> in
                guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

                let results = OpenSeaCollectionDecoder.decode(json: json, results: sum)
                let fetchedCount = json.arrayValue.count
                if fetchedCount > 0 {
                    return strongSelf.fetchCollectionsPage(forOwner: owner, offset: offset + fetchedCount, sum: results)
                } else {
                    return .value(sum)
                }
            }).recover { _ -> Promise<[OpenSea.CollectionKey: OpenSea.Collection]> in
                //NOTE: return some already fetched amount
                return .value(sum)
            }
    }

    private static func performOpenSeaRequest(url: URL, maximumRetryCount: Int = 3, delayMultiplayer: Int = 5, retryDelay: DispatchTimeInterval = .seconds(2), queue: DispatchQueue) -> Promise<JSON> {
        struct OpenSeaRequestTrottled: Error {}

        func privatePerformOpenSeaRequest(url: URL) -> Promise<(HTTPURLResponse, JSON)> {
            return OpenSea.sessionManagerWithDefaultHttpHeaders
                .request(url, method: .get, headers: ["X-API-KEY": Constants.Credentials.openseaKey])
                .responseJSON(queue: queue, options: .allowFragments)
                .map(on: queue, { response -> (HTTPURLResponse, JSON) in
                    guard let data = response.response.data, let json = try? JSON(data: data), let httpResponse = response.response.response else {
                        throw AnyError(OpenSeaError(localizedDescription: "Error calling \(url)"))
                    }
                    return (httpResponse, json)
                })
        }
        
        var delayUpperRangeValueFrom0To: Int = delayMultiplayer
        return firstly {
            attempt(maximumRetryCount: maximumRetryCount, delayBeforeRetry: retryDelay, delayUpperRangeValueFrom0To: delayUpperRangeValueFrom0To) {
                privatePerformOpenSeaRequest(url: url).map { (httpResponse, json) -> (HTTPURLResponse, JSON) in
                    guard httpResponse.statusCode != 429 else {
                        delayUpperRangeValueFrom0To += delayMultiplayer
                        throw OpenSeaRequestTrottled()
                    }

                    return (httpResponse, json)
                }
            }.map { (_, json) -> JSON in
                return json
            }
        }
    }

    private func fetchAssetsPage(forOwner owner: AlphaWallet.Address, offset: Int, assets: [AlphaWallet.Address: [OpenSeaNonFungible]] = [:]) -> Promise< [AlphaWallet.Address: [OpenSeaNonFungible]]> {
        let baseURL = OpenSea.getBaseURLForOpensea(for: key.server)
        //Careful to `order_by` with a valid value otherwise OpenSea will return 0 results
        guard let url = URL(string: "\(baseURL)api/v1/assets/?owner=\(owner.eip55String)&order_by=pk&order_direction=asc&limit=50&offset=\(offset)") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return OpenSea.performOpenSeaRequest(url: url, queue: queue)
            .then({ [weak self] json -> Promise<[AlphaWallet.Address: [OpenSeaNonFungible]]> in
                guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

                let results = OpenSeaAssetDecoder.decode(json: json, assets: assets)
                let fetchedCount = json["assets"].count
                if fetchedCount > 0 {
                    return strongSelf.fetchAssetsPage(forOwner: owner, offset: offset + fetchedCount, assets: results)
                } else {
                    //Ignore UEFA from OpenSea, otherwise the token type would be saved wrongly as `.erc721` instead of `.erc721ForTickets`
                    let assetsExcludingUefa = assets.filter { !$0.key.isUEFATicketContract }

                    return .value(assetsExcludingUefa)
                }
            }).recover { _ -> Promise< [AlphaWallet.Address: [OpenSeaNonFungible]]> in
                //NOTE: return some already fetched amount
                let assetsExcludingUefa = assets.filter { !$0.key.isUEFATicketContract }
                return .value(assetsExcludingUefa)
            }
    }

    private func cachePromise(withTokenIdCount tokenIdCount: Int, forOwner wallet: AlphaWallet.Address) {
        guard tokenIdCount >= OpenSea.numberOfTokenIdsBeforeRateLimitingRequests else { return }
        recentWalletsWithManyTokens[wallet] = (Date(), fetch)
    }

    private func cachedPromise(forOwner wallet: AlphaWallet.Address) -> Promise<OpenSeaNonFungiblesToAddress>? {
        guard let (_, promise) = recentWalletsWithManyTokens[wallet] else { return nil }
        return promise
    }

    private func trimCachedPromises() {
        let cachedWallets = recentWalletsWithManyTokens.keys
        let now = Date()
        for each in cachedWallets {
            guard let (date, _) = recentWalletsWithManyTokens[each] else { continue }
            if now.timeIntervalSince(date) >= OpenSea.minimumSecondsBetweenRequests {
                recentWalletsWithManyTokens.removeValue(forKey: each)
            }
        }
    } 
}
