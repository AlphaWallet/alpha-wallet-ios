//
//  OpenSeaNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.03.2022.
//

import Alamofire
import BigInt
import PromiseKit
import Result
import SwiftyJSON

final class OpenSeaNetworkProvider {

    private let sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30

        return SessionManager(configuration: configuration)
    }()

    private let queue: DispatchQueue

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func fetchAssetsPromise(address owner: AlphaWallet.Address, server: RPCServer) -> Promise<OpenSea.Response<OpenSeaNonFungiblesToAddress>> {
        let offset = 0
        //NOTE: some of OpenSea collections have an empty `primary_asset_contracts` array, so we are not able to identifyto each asset connection relates. it solves with `slug` field for collection. We match assets `slug` with collections `slug` values for identification
        func findCollection(address: AlphaWallet.Address, asset: OpenSeaNonFungible, collections: [OpenSea.CollectionKey: OpenSea.Collection]) -> OpenSea.Collection? {
            return collections[.address(address)] ?? collections[.slug(asset.slug)]
        }

        //NOTE: Due to OpenSea's policy of sending requests, (we are not able to sent multiple requests, the request trottled, and 1 sec delay is needed)
        //to send a new one. First we send fetch assets requests and then fetch collections requests
        typealias OpenSeaAssetsAndCollections = (OpenSeaNonFungiblesToAddress, [OpenSea.CollectionKey: OpenSea.Collection])

        let assetsPromise = fetchAssetsPage(forOwner: owner, server: server, offset: offset)
        let collectionsPromise = fetchCollectionsPage(forOwner: owner, server: server, offset: offset)

        return when(resolved: [assetsPromise.asVoid(), collectionsPromise.asVoid()])
            .map(on: queue, { _ -> OpenSea.Response<OpenSeaNonFungiblesToAddress> in

                let assetsExcludingUefa = assetsPromise.result?.optionalValue ?? .init(hasError: true, result: [:])
                let collections = collectionsPromise.result?.optionalValue ?? .init(hasError: true, result: [:])

                var result: [AlphaWallet.Address: [OpenSeaNonFungible]] = [:]
                for each in assetsExcludingUefa.result {
                    let updatedElements = each.value.map { openSeaNonFungible -> OpenSeaNonFungible in
                        var openSeaNonFungible = openSeaNonFungible
                        let collection = findCollection(address: each.key, asset: openSeaNonFungible, collections: collections.result)
                        openSeaNonFungible.collection = collection

                        return openSeaNonFungible
                    }

                    result[each.key] = updatedElements
                }
                let hasError = assetsExcludingUefa.hasError || collections.hasError

                return .init(hasError: hasError, result: result)
            })
            .recover({ _ -> Promise<OpenSea.Response<OpenSeaNonFungiblesToAddress>> in
                return .value(.init(hasError: true, result: [:]))
            })
    }

    private func getBaseURLForOpensea(for server: RPCServer) -> String {
        switch server {
        case .main:
            return Constants.openseaAPI
        case .rinkeby:
            return Constants.openseaRinkebyAPI
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet:
            return Constants.openseaAPI
        }
    }

    func fetchAssetImageUrl(for value: Eip155URL, server: RPCServer) -> Promise<URL> {
        let baseURL = getBaseURLForOpensea(for: server)
        guard let url = URL(string: "\(baseURL)api/v1/asset/\(value.path)") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return performRequestWithRetry(server: server, url: url, queue: .main).map { json -> URL in
            let image: String = json["image_url"].string ?? json["image_preview_url"].string ?? json["image_thumbnail_url"].string ?? json["image_original_url"].string ?? ""
            guard let url = URL(string: image) else {
                throw AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL)"))
            }
            return url
        }
    }

    func collectionStats(slug: String, server: RPCServer) -> Promise<OpenSea.Stats> {
        let baseURL = getBaseURLForOpensea(for: server)
        guard let url = URL(string: "\(baseURL)api/v1/collection/\(slug)/stats") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return performRequestWithRetry(server: server, url: url, queue: .main).map { json -> OpenSea.Stats in
            return try OpenSea.Stats(json: json)
        }
    }

    private func fetchCollectionsPage(forOwner owner: AlphaWallet.Address, server: RPCServer, offset: Int, sum: [OpenSea.CollectionKey: OpenSea.Collection] = [:]) -> Promise<OpenSea.Response<[OpenSea.CollectionKey: OpenSea.Collection]>> {
        let baseURL = getBaseURLForOpensea(for: server)
        guard let url = URL(string: "\(baseURL)api/v1/collections?asset_owner=\(owner.eip55String)&limit=300&offset=\(offset)") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return performRequestWithRetry(server: server, url: url, queue: queue)
            .then(on: queue, { [weak self] json -> Promise<OpenSea.Response<[OpenSea.CollectionKey: OpenSea.Collection]>> in
                guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

                let results = OpenSeaCollectionDecoder.decode(json: json, results: sum)
                let fetchedCount = json.arrayValue.count
                if fetchedCount > 0 {
                    return strongSelf.fetchCollectionsPage(forOwner: owner, server: server, offset: offset + fetchedCount, sum: results)
                } else {
                    return .value(.init(hasError: false, result: sum))
                }
            })
            .recover { _ -> Promise<OpenSea.Response<[OpenSea.CollectionKey: OpenSea.Collection]>> in
                //NOTE: return some already fetched amount
                return .value(.init(hasError: true, result: sum))
            }
    }

    private func openSeaKey(forServer server: RPCServer) -> String? {
        switch server {
        case .main:
            return Constants.Credentials.openseaKey
        case .rinkeby, .klaytnCypress, .klaytnBaobabTestnet:
            //We don't return the key because OpenSea API returns a `401` with body "Invalid API key" when a key is used with Rinkeby
            return nil
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            //We are just being safe here, returning the key anyway
            return Constants.Credentials.openseaKey
        }
    }

    private func performRequestWithRetry(server: RPCServer, url: URL, maximumRetryCount: Int = 3, delayMultiplayer: Int = 5, retryDelay: DispatchTimeInterval = .seconds(2), queue: DispatchQueue) -> Promise<JSON> {
        enum OpenSeaApiError: Error {
            case rateLimited
            case invalidApiKey
        }

        func privatePerformRequest(url: URL) -> Promise<(HTTPURLResponse, JSON)> {
            var headers: [String: String] = .init()
            headers["X-API-KEY"] = openSeaKey(forServer: server)
            //Using responseData() instead of responseJSON() below because `PromiseKit`'s `responseJSON()` resolves to failure if body isn't JSON. But OpenSea returns a non-JSON when the status code is 401 (unauthorized, aka. wrong API key) and we want to detect that.
            return sessionManagerWithDefaultHttpHeaders
                .request(url, method: .get, headers: headers)
                .responseData()
                .map(on: queue, { data, response -> (HTTPURLResponse, JSON) in
                    if let response: HTTPURLResponse = response.response {
                        let statusCode = response.statusCode
                        if statusCode == 401 {
                            throw OpenSeaApiError.invalidApiKey
                        } else if statusCode == 429 {
                            throw OpenSeaApiError.rateLimited
                        }
                        if let json = try? JSON(data: data) {
                            return (response, json)
                        } else {
                            throw AnyError(OpenSeaError(localizedDescription: "Error calling \(url)"))
                        }
                    } else {
                        throw AnyError(OpenSeaError(localizedDescription: "Error calling \(url)"))
                    }
                })
        }

        let delayUpperRangeValueFrom0To: Int = delayMultiplayer
        return firstly {
            attempt(maximumRetryCount: maximumRetryCount, delayBeforeRetry: retryDelay, delayUpperRangeValueFrom0To: delayUpperRangeValueFrom0To) {
                privatePerformRequest(url: url).map { _, json -> JSON in
                    json
                }
            }.recover { error -> Promise<JSON> in
                infoLog("[OpenSea] API error: \(error)")
                throw error
            }
        }
    }

    private func fetchAssetsPage(forOwner owner: AlphaWallet.Address, server: RPCServer, offset: Int, assets: OpenSeaNonFungiblesToAddress = [:]) -> Promise<OpenSea.Response<OpenSeaNonFungiblesToAddress>> {
        let baseURL = getBaseURLForOpensea(for: server)
        //Careful to `order_by` with a valid value otherwise OpenSea will return 0 results
        guard let url = URL(string: "\(baseURL)api/v1/assets/?owner=\(owner.eip55String)&order_by=pk&order_direction=asc&limit=50&offset=\(offset)") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)")))
        }

        return performRequestWithRetry(server: server, url: url, queue: queue)
            .then({ [weak self] json -> Promise<OpenSea.Response<OpenSeaNonFungiblesToAddress>> in
                guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

                let results = OpenSeaAssetDecoder.decode(json: json, assets: assets)
                let fetchedCount = json["assets"].count
                if fetchedCount > 0 {
                    return strongSelf.fetchAssetsPage(forOwner: owner, server: server, offset: offset + fetchedCount, assets: results)
                } else {
                    //Ignore UEFA from OpenSea, otherwise the token type would be saved wrongly as `.erc721` instead of `.erc721ForTickets`
                    let assetsExcludingUefa = assets.filter { !$0.key.isUEFATicketContract }

                    return .value(.init(hasError: false, result: assetsExcludingUefa))
                }
            })
            .recover { _ -> Promise<OpenSea.Response<OpenSeaNonFungiblesToAddress>> in
                //NOTE: return some already fetched amount
                let assetsExcludingUefa = assets.filter { !$0.key.isUEFATicketContract }
                return .value(.init(hasError: true, result: assetsExcludingUefa))
            }
    }
}

extension OpenSea {
    //NOTE: we want to keep response data  even when request has failure while performing multiple page, that is why we use `hasError` flag to determine wether data can be saved to local storage with replacing or merging with existing data
    struct Response<T> {
        let hasError: Bool
        let result: T
    }
}
