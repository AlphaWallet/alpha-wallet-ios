//
//  NftAssetsPageDecoder.swift
//  AlphaWalletOpenSea
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import BigInt
import SwiftyJSON

struct NftAssetsFilter {
    let assets: [AlphaWallet.Address: [NftAsset]]

    func assets(excluding excludeContracts: [(AlphaWallet.Address, RPCServer)]) -> [AlphaWallet.Address: [NftAsset]] {
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
        let results = (json["nfts"].array ?? json["assets"].array ?? json["results"].array ?? [])
        let nextPage = json["next"].string
        for each in results {
            guard let nftAsset = NftAsset(json: each) else { continue }
            let contract = nftAsset.contract
            var list = assets[contract, default: []]
            list.append(nftAsset)
            assets[contract] = list
        }
        return .init(assets: assets, count: results.count, next: nextPage, error: nil)
    }
}

extension NftAsset {
    init?(json: JSON) {
        guard let contract = AlphaWallet.Address(string: json["contract"].stringValue) else { return nil }
        //Some results from OpenSea are .erc20. We exclude those
        guard let tokenType = NonFungibleFromJsonTokenType(rawValue: json["token_standard"].stringValue) else { return nil }
        let tokenId = json["token_id"].stringValue
        let decimals: Int = 0
        let value: BigInt
        switch tokenType {
        case .erc721:
            value = 1
        case .erc1155:
            value = 0
        }
        let name = json["name"].stringValue
        let description = json["description"].stringValue
        let collectionId = json["collection"].stringValue

        //Images might be limited to "image_url" as of OpenSea API v2
        let thumbnailUrl = json["image_thumbnail_url"].stringValue
        //We'll get what seems to be the PNG version first, falling back to the sometimes PNG, but sometimes SVG version
        var imageUrl = json["image_preview_url"].stringValue
        if imageUrl.isEmpty {
            imageUrl = json["image_url"].stringValue
        }
        let previewUrl = json["image_preview_url"].stringValue
        let imageOriginalUrl = json["image_original_url"].stringValue

        //We'll get the real one from the collection level later
        let contractImageUrl = json["image_url"].stringValue
        let externalLink = json["external_link"].string ?? json["project_url"].stringValue
        let backgroundColor = json["background_color"].stringValue

        //TODO have to fetch single NFTs from OpenSea v2 API to get traits, animation_url and creator contract https://docs.opensea.io/reference/get_nft The creator information has to be fetched with an additional call. Maybe make these 2 calls when the user tap to show the token?
        //TODO use "metadata_url" if it's useful: "https://resources.smarttokenlabs.com/137/0xd5ca946ac1c1f24eb26dae9e1a53ba6a02bd97fe/1913046616" Might also access it first before OpenSea API?
        let animationUrl = json["animation_url"].string
        let traits = json["traits"].arrayValue.compactMap { OpenSeaNonFungibleTrait(json: $0) }
        let creator = try? AssetCreator(json: json["creator"])

        self.init(contract: contract, tokenId: tokenId, tokenType: tokenType, value: value, contractName: "", decimals: decimals, symbol: "", name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, contractImageUrl: contractImageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits, collectionCreatedDate: nil, collectionDescription: nil, creator: creator, collectionId: collectionId, imageOriginalUrl: imageOriginalUrl, previewUrl: previewUrl, animationUrl: animationUrl)
    }
}
