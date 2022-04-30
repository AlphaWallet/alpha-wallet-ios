//
//  OpenSeaCollectionDecoder.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import SwiftyJSON

public struct OpenSeaCollectionDecoder {
    public static func decode(json: JSON, results: [CollectionKey: Collection]) -> [CollectionKey: Collection] {
        var results = results

        for each in json.arrayValue {
            guard let collection = try? Collection(json: each) else {
                continue
            }

            if collection.contracts.isEmpty {
                results[CollectionKey.slug(collection.slug)] = collection
            } else {
                for each in collection.contracts {
                    results[CollectionKey.address(each.address)] = collection
                }
            }
        }

        return results
    }
}