//
//  OpenSeaCollection.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import SwiftyJSON

extension OpenSea {

    enum CollectionKey: Hashable {
        case address(AlphaWallet.Address)
        case slug(String)
    }

    struct PrimaryAssetContract: Codable {
        let address: AlphaWallet.Address
        let assetContractType: String
        let createdDate: String
        let name: String
        let nftVersion: String
        let schemaName: String
        let symbol: String
        let owner: String
        let totalSupply: String
        let description: String
        let externalLink: String
        let imageUrl: String

        init(json: JSON) throws {
            guard let address = AlphaWallet.Address(string: json["address"].stringValue) else {
                throw OpenSeaAssetDecoder.DecoderError.jsonInvalidError
            }

            self.address = address
            assetContractType = json["asset_contract_type"].stringValue
            createdDate = json["created_date"].stringValue
            name = json["name"].stringValue
            nftVersion = json["nft_version"].stringValue
            schemaName = json["schema_name"].stringValue
            symbol = json["symbol"].stringValue
            owner = json["owner"].stringValue
            totalSupply = json["total_supply"].stringValue
            description = json["description"].stringValue
            externalLink = json["external_link"].stringValue
            imageUrl = json["image_url"].stringValue
        }
    }

    struct Collection: Codable {
        let ownedAssetCount: Int
        let wikiUrl: String?
        let instagramUsername: String?
        let twitterUsername: String?
        let discordUrl: String?
        let telegramUrl: String?
        let shortDescription: String?
        let bannerImageUrl: String?
        let chatUrl: String?
        let createdDate: String?
        let defaultToFiat: Bool
        let descriptionString: String
        var stats: Stats?
        let name: String
        let externalUrl: String?
        let slug: String
        let contracts: [PrimaryAssetContract]

        init(json: JSON) throws {
            contracts = json["primary_asset_contracts"].arrayValue.compactMap { json in
                return try? PrimaryAssetContract(json: json)
            }
            slug = json["slug"].stringValue

            ownedAssetCount = json["owned_asset_count"].intValue
            wikiUrl = json["wiki_url"].stringValue
            instagramUsername = json["instagram_username"].string
            twitterUsername = json["twitter_username"].string
            discordUrl = json["discord_url"].string
            telegramUrl = json["telegram_url"].string
            shortDescription = json["short_description"].string
            bannerImageUrl = json["banner_image_url"].string
            chatUrl = json["chat_url"].stringValue
            createdDate = json["created_date"].stringValue
            defaultToFiat = json["default_to_fiat"].boolValue
            descriptionString = json["description"].stringValue
            stats = try Stats(json: json)
            name = json["name"].stringValue
            externalUrl = json["external_url"].string
        }
    }

    struct AssetCreator: Codable {
        let contractAddress: AlphaWallet.Address
        let config: String
        let profileImageUrl: URL?
        let user: String?

        init(json: JSON) throws {
            guard let address = AlphaWallet.Address(string: json["address"].stringValue) else {
                throw OpenSeaAssetDecoder.DecoderError.jsonInvalidError
            }
            self.contractAddress = address
            self.config = json["config"].stringValue
            self.profileImageUrl = json["profile_img_url"].string.flatMap { URL(string: $0.trimmed) }
            self.user = json["user"]["username"].string
        }
    }

}
