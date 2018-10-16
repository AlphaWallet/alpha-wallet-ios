// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import PromiseKit
import Result
import SwiftyJSON

class OpenSea {
    static let sharedInstance = OpenSea()
    var fetch = OpenSea.makeEmptyFulfilledPromise()

    private static func makeEmptyFulfilledPromise() -> Promise<ResultResult<[String: [OpenSeaNonFungible]], AnyError>.t> {
        return Promise {
            $0.fulfill(.success([:]))
        }
    }

    ///Call this after switching wallets, otherwise when the current promise is fulfilled, the switched to wallet will think the API results are for them
    func reset() {
        fetch = OpenSea.makeEmptyFulfilledPromise()
    }

    ///Uses a promise to make sure we don't fetch from OpenSea multiple times concurrently
    func makeFetchPromise(owner: String) -> Promise<ResultResult<[String: [OpenSeaNonFungible]], AnyError>.t> {
        if fetch.isResolved {
            fetch = Promise { seal in
                let offset = 0
                fetchPage(forOwner: owner, offset: offset) { result in
                    seal.fulfill(result)
                }
            }
        }
        return fetch
    }

    private func fetchPage(forOwner owner: String, offset: Int, sum: [String: [OpenSeaNonFungible]] = [:], completion: @escaping (ResultResult<[String: [OpenSeaNonFungible]], AnyError>.t) -> Void) {
        guard let url = URL(string: "\(Constants.openseaAPI)api/v1/assets/?owner=\(owner)&order_by=current_price&order_direction=asc&limit=2000&offset=\(offset)") else {
            completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(Constants.openseaAPI) API \(Thread.isMainThread)"))))
            return
        }
        Alamofire.request(
                url,
                method: .get,
                headers: ["X-API-KEY": Constants.openseaAPIKEY]
        ).responseJSON { response in
            guard let data = response.data, let json = try? JSON(data: data) else {
                completion(.failure(AnyError(OpenSeaError(localizedDescription: "Error calling \(Constants.openseaAPI) API"))))
                return
            }
            var results = sum
            var currentPageCount = 0
            for (_, each): (String, JSON) in json["assets"] {
                let tokenId = each["token_id"].stringValue
                let contractName = each["asset_contract"]["name"].stringValue
                let symbol = each["asset_contract"]["symbol"].stringValue
                let name = each["name"].stringValue
                let description = each["description"].stringValue
                let thumbnailUrl = each["image_thumbnail_url"].stringValue
                let imageUrl = each["image_url"].stringValue
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
                let contract = each["asset_contract"]["address"].stringValue
                let cat = OpenSeaNonFungible(tokenId: tokenId, contractName: contractName, symbol: symbol, name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits)
                currentPageCount += 1
                if var list = results[contract] {
                    list.append(cat)
                    results[contract] = list
                } else {
                    let list = [cat]
                    results[contract] = list
                }
            }
            if currentPageCount > 0 {
                self.fetchPage(forOwner: owner, offset: offset + currentPageCount, sum: results) { results in
                    completion(results)
                }
            } else {
                completion(.success(sum))
            }
        }
    }
}
