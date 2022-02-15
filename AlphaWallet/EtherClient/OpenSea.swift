// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import PromiseKit
import Result
import SwiftyJSON

class OpenSea {
    typealias PromiseResult = Promise<[AlphaWallet.Address: [OpenSeaNonFungible]]>

    //Assuming 1 token (token ID, rather than a token) is 4kb, 1500 HyperDragons is 6MB. So we rate limit requests
    private static let numberOfTokenIdsBeforeRateLimitingRequests = 25
    private static let minimumSecondsBetweenRequests = TimeInterval(60)
    private static let dateFormatter: DateFormatter = {
        //Expect date string from asset_contract/created_date, etc as: "2020-05-27T16:53:32.834583"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormatter
    }()
    private static var instances = [AddressAndRPCServer: WeakRef<OpenSea>]()
    //NOTE: using AddressAndRPCServer fixes issue with incorrect tokens returned from makeFetchPromise
    // the problem was that cached OpenSea returned tokens from multiple wallets
    private let key: AddressAndRPCServer
    private var recentWalletsWithManyTokens = [AlphaWallet.Address: (Date, PromiseResult)]()
    private var fetch = OpenSea.makeEmptyFulfilledPromise()
    private let queue = DispatchQueue.global(qos: .userInitiated)

    private init(key: AddressAndRPCServer) {
        self.key = key
    }

    static func createInstance(with key: AddressAndRPCServer) -> OpenSea {
        if let instance = instances[key]?.object {
            return instance
        } else {
            let instance = OpenSea(key: key)
            instances[key] = WeakRef(object: instance)
            return instance
        }
    }

    private static func makeEmptyFulfilledPromise() -> PromiseResult {
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
    func makeFetchPromise() -> PromiseResult {
        guard OpenSea.isServerSupported(key.server) else {
            fetch = .value([:])
            return fetch
        }
        let owner = key.address
        trimCachedPromises()
        if let cachedPromise = cachedPromise(forOwner: owner) {
            return cachedPromise
        }

        if fetch.isResolved {
            fetch = Promise { seal in
                let offset = 0
                fetchPage(forOwner: owner, offset: offset) { result in
                    switch result {
                    case .success(let result):

                        seal.fulfill(result)
                    case .failure(let error):
                        verboseLog("[OpenSea] fetch failed: \(error) owner: \(owner.eip55String) offset: \(offset)")
                        seal.reject(error)
                    }
                }
            }
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

    static func fetchAsset(for value: Eip155URL) -> Promise<URL> {
        let baseURL = getBaseURLForOpensea(for: .main)
        guard let url = URL(string: "\(baseURL)api/v1/asset/\(value.path)") else {
            return .init(error: AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")))
        }

        return Promise<URL> { seal in
            Alamofire
                .request(url, method: .get, headers: ["X-API-KEY": Constants.Credentials.openseaKey])
                .responseJSON(queue: .main, options: .allowFragments, completionHandler: { response in
                    guard let data = response.data, let json = try? JSON(data: data) else {
                        return seal.reject(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API: \(String(describing: response.error))")))
                    }

                    let image: String = json["image_url"].string ?? json["image_preview_url"].string ?? json["image_thumbnail_url"].string ?? json["image_original_url"].string ?? ""
                    guard let url = URL(string: image) else {
                        return seal.reject(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API: \(String(describing: response.error))")))
                    }
                    seal.fulfill(url)
            })
        }
    }

    private func fetchPage(forOwner owner: AlphaWallet.Address, offset: Int, sum: [AlphaWallet.Address: [OpenSeaNonFungible]] = [:], completion: @escaping (ResultResult<[AlphaWallet.Address: [OpenSeaNonFungible]], AnyError>.t) -> Void) {
        let baseURL = Self.getBaseURLForOpensea(for: key.server)
        //Careful to `order_by` with a valid value otherwise OpenSea will return 0 results
        guard let url = URL(string: "\(baseURL)api/v1/assets/?owner=\(owner.eip55String)&order_by=pk&order_direction=asc&limit=50&offset=\(offset)") else {
            completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)"))))
            return
        }

        Alamofire.request(
                url,
                method: .get,
                headers: ["X-API-KEY": Constants.Credentials.openseaKey]
        ).responseJSON(queue: queue, options: .allowFragments, completionHandler: { [weak self] response in
            guard let strongSelf = self else { return }
            guard let data = response.data, let json = try? JSON(data: data) else {
                completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API: \(String(describing: response.error))"))))
                return
            }

            var results = sum
            for (_, each): (String, JSON) in json["assets"] {
                let type = each["asset_contract"]["schema_name"].stringValue
                guard let tokenType = NonFungibleFromJsonTokenType(rawString: type) else { continue }
                if !Features.isErc1155Enabled && tokenType == .erc1155 { continue }
                let tokenId = each["token_id"].stringValue
                let contractName = each["asset_contract"]["name"].stringValue
                //So if it's null in OpenSea, we get a 0, as expected. And 0 works for ERC721 too
                let decimals = each["decimals"].intValue
                let value: BigInt
                switch tokenType {
                case .erc721:
                    value = 1
                case .erc1155:
                    //OpenSea API doesn't include value for ERC1155, so we'll have to batch fetch it later for each contract before we update the database
                    value = 0
                }
                let symbol = each["asset_contract"]["symbol"].stringValue
                let name = each["name"].stringValue
                let description = each["description"].stringValue
                let thumbnailUrl = each["image_thumbnail_url"].stringValue
                //We'll get what seems to be the PNG version first, falling back to the sometimes PNG, but sometimes SVG version
                var imageUrl = each["image_preview_url"].stringValue
                if imageUrl.isEmpty {
                    imageUrl = each["image_url"].stringValue
                }
                let contractImageUrl = each["asset_contract"]["image_url"].stringValue
                let externalLink = each["external_link"].stringValue
                let backgroundColor = each["background_color"].stringValue
                var traits = [OpenSeaNonFungibleTrait]()
                for each in each["traits"].arrayValue {
                    let traitCount = each["trait_count"].intValue
                    let traitType = each["trait_type"].stringValue
                    let traitValue = each["value"].stringValue
                    let trait = OpenSeaNonFungibleTrait(count: traitCount, type: traitType, value: traitValue)
                    traits.append(trait)
                }
                if let contract = AlphaWallet.Address(string: each["asset_contract"]["address"].stringValue) {
                    let collectionCreatedDate = each["asset_contract"]["created_date"].string.flatMap { OpenSea.dateFormatter.date(from: $0) }
                    let collectionDescription = each["asset_contract"]["description"].string
                    let cat = OpenSeaNonFungible(tokenId: tokenId, tokenType: tokenType, value: value, contractName: contractName, decimals: decimals, symbol: symbol, name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, contractImageUrl: contractImageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits, collectionCreatedDate: collectionCreatedDate, collectionDescription: collectionDescription)
                    if var list = results[contract] {
                        list.append(cat)
                        results[contract] = list
                    } else {
                        let list = [cat]
                        results[contract] = list
                    }
                }
            }

            let fetchedCount = json["assets"].count
            verboseLog("[OpenSea] fetch page count: \(fetchedCount) owner: \(owner.eip55String) offset: \(offset)")
            if fetchedCount > 0 {
                strongSelf.fetchPage(forOwner: owner, offset: offset + fetchedCount, sum: results) { results in
                    completion(results)
                }
            } else {
                //Ignore UEFA from OpenSea, otherwise the token type would be saved wrongly as `.erc721` instead of `.erc721ForTickets`
                let excludingUefa = sum.filter { !$0.key.isUEFATicketContract }
                var tokenIdCount = 0
                for (_, tokenIds) in excludingUefa {
                    tokenIdCount += tokenIds.count
                }
                strongSelf.cachePromise(withTokenIdCount: tokenIdCount, forOwner: owner)

                completion(.success(excludingUefa))
            }
        })
    }

    private func cachePromise(withTokenIdCount tokenIdCount: Int, forOwner wallet: AlphaWallet.Address) {
        guard tokenIdCount >= OpenSea.numberOfTokenIdsBeforeRateLimitingRequests else { return }
        recentWalletsWithManyTokens[wallet] = (Date(), fetch)
    }

    private func cachedPromise(forOwner wallet: AlphaWallet.Address) -> PromiseResult? {
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
