//
//  OpenSeaAssetDecoder.swift
//  AlphaWalletOpenSea
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import AlphaWalletAddress
import BigInt
import SwiftyJSON

public struct OpenSeaAssetDecoder {
    enum DecoderError: Error {
        case jsonInvalidError
        case statsDecoding
        case requestWasThrottled
    }

    static let dateFormatter: DateFormatter = {
        //Expect date string from asset_contract/created_date, etc as: "2020-05-27T16:53:32.834583"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormatter
    }()

    static func decode(json: JSON, assets: [AlphaWallet.Address: [OpenSeaNonFungible]]) -> [AlphaWallet.Address: [OpenSeaNonFungible]] {
        var assets = assets

        for (_, each): (String, JSON) in json["assets"] {
            let assetContractJson = each["asset_contract"]
            let collectionJson = each["collection"]

            guard let contract = AlphaWallet.Address(string: assetContractJson["address"].stringValue) else {
                continue
            }
            guard let tokenType = NonFungibleFromJsonTokenType(rawString: assetContractJson["schema_name"].stringValue) else {
                continue
            }
            let tokenId = each["token_id"].stringValue
            let contractName = assetContractJson["name"].stringValue
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
            let symbol = assetContractJson["symbol"].stringValue
            let name = each["name"].stringValue
            let description = each["description"].stringValue
            let thumbnailUrl = each["image_thumbnail_url"].stringValue
            //We'll get what seems to be the PNG version first, falling back to the sometimes PNG, but sometimes SVG version
            var imageUrl = each["image_preview_url"].stringValue
            if imageUrl.isEmpty {
                imageUrl = each["image_url"].stringValue
            }
            let contractImageUrl = assetContractJson["image_url"].stringValue
            let externalLink = each["external_link"].stringValue
            let backgroundColor = each["background_color"].stringValue

            let traits = each["traits"].arrayValue.compactMap { OpenSeaNonFungibleTrait(json: $0) }
            let slug = collectionJson["slug"].stringValue
            let collectionCreatedDate = assetContractJson["created_date"].string
                    .flatMap { OpenSeaAssetDecoder.dateFormatter.date(from: $0) }
            let collectionDescription = assetContractJson["description"].string
            let creator = try? AssetCreator(json: each["creator"])

            let cat = OpenSeaNonFungible(tokenId: tokenId, tokenType: tokenType, value: value, contractName: contractName, decimals: decimals, symbol: symbol, name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, contractImageUrl: contractImageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits, collectionCreatedDate: collectionCreatedDate, collectionDescription: collectionDescription, creator: creator, slug: slug)

            if var list = assets[contract] {
                list.append(cat)
                assets[contract] = list
            } else {
                let list = [cat]
                assets[contract] = list
            }
        }

        return assets
    }
}