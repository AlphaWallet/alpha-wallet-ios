// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import PromiseKit
import Result
import SwiftyJSON

class OpenSea {
    typealias PromiseResult = Promise<[AlphaWallet.Address: [OpenSeaNonFungible]]>

    //Assuming 1 token (token ID, rather than a token) is 4kb, 1500 HyperDragons is 6MB. So we rate limit requests
    private static let numberOfTokenIdsBeforeRateLimitingRequests = 25
    private static let minimumSecondsBetweenRequests = TimeInterval(60)
    static let sharedInstance = OpenSea()

    private var recentWalletsWithManyTokens = [AlphaWallet.Address: (Date, PromiseResult)]()
    private var fetch = OpenSea.makeEmptyFulfilledPromise()

    private static func makeEmptyFulfilledPromise() -> PromiseResult {
        return Promise {
            $0.fulfill([:])
        }
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main, .rinkeby:
            return true
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai:
            return false
        }
    }

    ///Call this after switching wallets, otherwise when the current promise is fulfilled, the switched to wallet will think the API results are for them
    func reset() {
        fetch = OpenSea.makeEmptyFulfilledPromise()
    }

    ///Uses a promise to make sure we don't fetch from OpenSea multiple times concurrently
    func makeFetchPromise(server: RPCServer, owner: AlphaWallet.Address) -> PromiseResult {
        guard OpenSea.isServerSupported(server) else {
            fetch = .value([:])
            return fetch
        }

        trimCachedPromises()
        if let cachedPromise = cachedPromise(forOwner: owner) {
            return cachedPromise
        }

        if fetch.isResolved {
            fetch = Promise { seal in
                let offset = 0
                fetchPage(forServer: server, owner: owner, offset: offset) { result in
                    switch result {
                    case .success(let result):
                        seal.fulfill(result)
                    case .failure(let error):
                        seal.reject(error)
                    }
                }
            }
        }
        return fetch
    }

    private func getBaseURLForOpensea(server: RPCServer) -> String {
        switch server {
        case .main:
            return Constants.openseaAPI
        case .rinkeby:
            return Constants.openseaRinkebyAPI
        default:
            return Constants.openseaAPI
        }
    }

    private func fetchPage(forServer server: RPCServer, owner: AlphaWallet.Address, offset: Int, sum: [AlphaWallet.Address: [OpenSeaNonFungible]] = [:], completion: @escaping (ResultResult<[AlphaWallet.Address: [OpenSeaNonFungible]], AnyError>.t) -> Void) {
        let baseURL = getBaseURLForOpensea(server: server)
        guard let url = URL(string: "\(baseURL)api/v1/assets/?owner=\(owner.eip55String)&order_by=current_price&order_direction=asc&limit=200&offset=\(offset)") else {
            completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)"))))
            return
        }
        Alamofire.request(
                url,
                method: .get,
                headers: ["X-API-KEY": Constants.openseaAPIKEY]
        ).responseJSON { response in
            guard let data = response.data, let json = try? JSON(data: data) else {
                completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API: \(String(describing: response.error))"))))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                var results = sum
                var currentPageCount = 0
                for (_, each): (String, JSON) in json["assets"] {
                    let type = each["asset_contract"]["schema_name"].stringValue
                    guard type == "ERC721" else { continue }
                    let tokenId = each["token_id"].stringValue
                    let contractName = each["asset_contract"]["name"].stringValue
                    let symbol = each["asset_contract"]["symbol"].stringValue
                    let name = each["name"].stringValue
                    let description = each["description"].stringValue
                    let thumbnailUrl = each["image_thumbnail_url"].stringValue
                    //We'll get what seems to be the PNG version first, falling back to the sometimes PNG, but sometimes SVG version
                    var imageUrl = each["image_preview_url"].stringValue
                    if imageUrl.isEmpty {
                        imageUrl = each["image_url"].stringValue
                    }
                    let contractImageUrl = each["asset_contract"]["featured_image_url"].stringValue
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
                        let cat = OpenSeaNonFungible(tokenId: tokenId, contractName: contractName, symbol: symbol, name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, contractImageUrl: contractImageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits)
                        currentPageCount += 1
                        if var list = results[contract] {
                            list.append(cat)
                            results[contract] = list
                        } else {
                            let list = [cat]
                            results[contract] = list
                        }
                    }
                }
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    if currentPageCount > 0 {
                        strongSelf.fetchPage(forServer: server, owner: owner, offset: offset + currentPageCount, sum: results) { results in
                            completion(results)
                        }
                    } else {
                        var tokenIdCount = 0
                        for (_, tokenIds) in sum {
                            tokenIdCount += tokenIds.count
                        }
                        strongSelf.cachePromise(withTokenIdCount: tokenIdCount, forOwner: owner)
                        completion(.success(sum))
                    }
                }
            }
        }
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
