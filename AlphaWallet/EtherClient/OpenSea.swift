// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import PromiseKit
import Result
import SwiftyJSON

class OpenSea {
    private class WeakRef<T: AnyObject> {
        weak var object: T?
        init(object: T) {
            self.object = object
        }
    }

    typealias PromiseResult = Promise<[AlphaWallet.Address: [OpenSeaNonFungible]]>

    //Assuming 1 token (token ID, rather than a token) is 4kb, 1500 HyperDragons is 6MB. So we rate limit requests
    private static let numberOfTokenIdsBeforeRateLimitingRequests = 25
    private static let minimumSecondsBetweenRequests = TimeInterval(60)
    private static var instances = [RPCServer: WeakRef<OpenSea>]()

    private let server: RPCServer
    private var recentWalletsWithManyTokens = [AlphaWallet.Address: (Date, PromiseResult)]()
    private var fetch = OpenSea.makeEmptyFulfilledPromise()

    private init(server: RPCServer) {
        self.server = server
    }

    static func createInstance(forServer server: RPCServer) -> OpenSea {
        if let instance = instances[server]?.object {
            return instance
        } else {
            let instance = OpenSea(server: server)
            instances[server] = WeakRef(object: instance)
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
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan:
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
    func makeFetchPromise(forOwner owner: AlphaWallet.Address) -> PromiseResult {
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
                fetchPage(forOwner: owner, offset: offset) { result in
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

    private func getBaseURLForOpensea() -> String {
        switch server {
        case .main:
            return Constants.openseaAPI
        case .rinkeby:
            return Constants.openseaRinkebyAPI
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan:
            return Constants.openseaAPI
        }
    }

    private func fetchPage(forOwner owner: AlphaWallet.Address, offset: Int, sum: [AlphaWallet.Address: [OpenSeaNonFungible]] = [:], completion: @escaping (ResultResult<[AlphaWallet.Address: [OpenSeaNonFungible]], AnyError>.t) -> Void) {
        let baseURL = getBaseURLForOpensea()
        guard let url = URL(string: "\(baseURL)api/v1/assets/?owner=\(owner.eip55String)&order_by=current_price&order_direction=asc&limit=50&offset=\(offset)") else {
            completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API \(Thread.isMainThread)"))))
            return
        }
        Alamofire.request(
                url,
                method: .get,
                headers: ["X-API-KEY": Constants.Credentials.openseaKey]
        ).responseJSON { response in
            guard let data = response.data, let json = try? JSON(data: data) else {
                completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(baseURL) API: \(String(describing: response.error))"))))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                var results = sum
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
                        let cat = OpenSeaNonFungible(tokenId: tokenId, contractName: contractName, symbol: symbol, name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, contractImageUrl: contractImageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits)
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
                    let fetchedCount = json["assets"].count
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
