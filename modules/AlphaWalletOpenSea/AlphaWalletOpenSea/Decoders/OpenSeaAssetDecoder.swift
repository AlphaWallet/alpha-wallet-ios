//
//  NftAssetsPageDecoder.swift
//  AlphaWalletOpenSea
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import AlphaWalletAddress
import BigInt
import SwiftyJSON

struct NftAssetsFilter {
    let assets: [AlphaWallet.Address: [NftAsset]]

    func assets(excluding excludeContracts: [(AlphaWallet.Address, ChainId)]) -> [AlphaWallet.Address: [NftAsset]] {
        let excludeContracts = excludeContracts.map { $0.0 }
        return assets.filter { asset in !excludeContracts.contains(asset.key) }
    }
}

struct NftAssetsPage {
    let assets: [AlphaWallet.Address: [NftAsset]]
    let count: Int
    let next: String?
    let error: Error?
}

struct NftCollectionsPage {
    let collections: [CollectionKey: NftCollection]
    let count: Int
    let hasNextPage: Bool
    let error: Error?
}

public struct NftAssetsPageDecoder {
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
    let assets: [AlphaWallet.Address: [NftAsset]]
    
    func decode(json: JSON) -> NftAssetsPage {
        var assets = assets
        let results = (json["assets"].array ?? json["results"].array ?? [])
        let nextPage = json["next"].string

        for each in results {
            guard let assetContract = try? PrimaryAssetContract(json: each["asset_contract"]) else {
                continue
            }
            let collection = NftCollection(json: each, contracts: [assetContract])
            guard let cat = NftAsset(json: each) else {
                continue
            }

            if var list = assets[assetContract.address] {
                list.append(cat)
                assets[assetContract.address] = list
            } else {
                let list = [cat]
                assets[assetContract.address] = list
            }
        }

        return .init(assets: assets, count: results.count, next: nextPage, error: nil)
    }
}

extension NftAsset {
    init?(json: JSON) {
        let assetContractJson = json["asset_contract"]
        let collectionJson = json["collection"]

        guard let contract = AlphaWallet.Address(string: assetContractJson["address"].stringValue) else {
            return nil
        }
        guard let tokenType = NonFungibleFromJsonTokenType(rawValue: assetContractJson["schema_name"].stringValue) else {
            return nil
        }
        let tokenId = json["token_id"].stringValue
        let contractName = assetContractJson["name"].stringValue
        //So if it's null in OpenSea, we get a 0, as expected. And 0 works for ERC721 too
        let decimals = json["decimals"].intValue
        let value: BigInt
        switch tokenType {
        case .erc721:
            value = 1
        case .erc1155:
            //OpenSea API doesn't include value for ERC1155, so we'll have to batch fetch it later for each contract before we update the database
            value = 0
        }
        let symbol = assetContractJson["symbol"].stringValue
        let name = json["name"].stringValue
        let description = json["description"].stringValue
        let thumbnailUrl = json["image_thumbnail_url"].stringValue
        //We'll get what seems to be the PNG version first, falling back to the sometimes PNG, but sometimes SVG version
        var imageUrl = json["image_preview_url"].stringValue
        if imageUrl.isEmpty {
            imageUrl = json["image_url"].stringValue
        }
        let previewUrl = json["image_preview_url"].stringValue
        let imageOriginalUrl = json["image_original_url"].stringValue
        let contractImageUrl = assetContractJson["image_url"].stringValue
        let externalLink = json["external_link"].stringValue
        let backgroundColor = json["background_color"].stringValue
        let animationUrl = json["animation_url"].string
        let traits = json["traits"].arrayValue.compactMap { OpenSeaNonFungibleTrait(json: $0) }
        let collectionId = collectionJson["slug"].stringValue
        let collectionCreatedDate = assetContractJson["created_date"].string
                .flatMap { NftAssetsPageDecoder.dateFormatter.date(from: $0) }
        let collectionDescription = assetContractJson["description"].string
        let creator = try? AssetCreator(json: json["creator"])

        self.init(tokenId: tokenId,
                  tokenType: tokenType,
                  value: value,
                  contractName: contractName,
                  decimals: decimals,
                  symbol: symbol,
                  name: name,
                  description: description,
                  thumbnailUrl: thumbnailUrl,
                  imageUrl: imageUrl,
                  contractImageUrl: contractImageUrl,
                  externalLink: externalLink,
                  backgroundColor: backgroundColor,
                  traits: traits,
                  collectionCreatedDate: collectionCreatedDate,
                  collectionDescription: collectionDescription,
                  creator: creator,
                  collectionId: collectionId,
                  imageOriginalUrl: imageOriginalUrl,
                  previewUrl: previewUrl,
                  animationUrl: animationUrl)
    }
}
