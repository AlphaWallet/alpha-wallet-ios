//
//  OpenSeaCollectionDecoder.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import SwiftyJSON

struct OpenSeaCollectionDecoder {
    let collections: [CollectionKey: NftCollection]

    func decode(json: JSON) -> NftCollectionsPage {
        var collections = collections

        for each in json.arrayValue {
            let contracts = json["primary_asset_contracts"].arrayValue.compactMap { try? PrimaryAssetContract(json: $0) }
            let collection = NftCollection(json: each, contracts: contracts)

            if collection.contracts.isEmpty {
                collections[CollectionKey.collectionId(collection.id)] = collection
            } else {
                for each in collection.contracts {
                    collections[CollectionKey.address(each.address)] = collection
                }
            }
        }

        return .init(collections: collections, count: json.arrayValue.count, hasNextPage: !json.arrayValue.isEmpty, error: nil)
    }
}
