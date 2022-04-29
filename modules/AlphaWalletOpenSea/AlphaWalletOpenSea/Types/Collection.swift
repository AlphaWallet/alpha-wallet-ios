//
//  Collection.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import SwiftyJSON

public struct Collection: Codable {
    public let ownedAssetCount: Int
    public let wikiUrl: String?
    public let instagramUsername: String?
    public let twitterUsername: String?
    public let discordUrl: String?
    public let telegramUrl: String?
    public let shortDescription: String?
    public let bannerImageUrl: String?
    public let chatUrl: String?
    public let createdDate: String?
    public let defaultToFiat: Bool
    public let descriptionString: String
    public var stats: Stats?
    public let name: String
    public let externalUrl: String?
    public let slug: String
    public let contracts: [PrimaryAssetContract]

    public init(json: JSON) throws {
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