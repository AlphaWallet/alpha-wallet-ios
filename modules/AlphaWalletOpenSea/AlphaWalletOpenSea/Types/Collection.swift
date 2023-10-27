//
//  Collection.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import SwiftyJSON

public struct NftCollection: Codable {
    public let id: String
    public var ownedAssetCount: Int
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
    public var stats: NftCollectionStats?
    public let name: String
    public let externalUrl: String?
    public let imageUrl: String?
    public let bannerUrl: String?

    init(json: JSON) {
        id = json["collection"].stringValue
        //To update later in the process
        ownedAssetCount = 0
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
        stats = json["stats"] != .null ? NftCollectionStats(json: json["stats"]) : nil
        name = json["name"].stringValue
        externalUrl = json["external_url"].string
        imageUrl = json["image_url"].string
        bannerUrl = json["banner_image_url"].string
    }
}
