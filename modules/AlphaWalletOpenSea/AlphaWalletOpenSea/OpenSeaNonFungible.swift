//
//  NftAsset.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import AlphaWalletAddress
import BigInt
import SwiftyJSON

//Some fields are duplicated across token IDs within the same contract like the contractName, symbol, contractImageUrl, etc. The space savings in the database aren't work the normalization
public struct NftAsset: Codable, Equatable, Hashable, NonFungibleFromJson {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(tokenId)
        hasher.combine(tokenType.rawValue)
        hasher.combine(value.description)
    }

    public static func == (lhs: NftAsset, rhs: NftAsset) -> Bool {
        return lhs.tokenId == rhs.tokenId
    }

    //Not every token might used the same name. This is just common in OpenSea
    public static let generationTraitName = "generation"
    static let cooldownIndexTraitName = "cooldown_index"

    public let contract: AlphaWallet.Address
    public let tokenId: String
    public let tokenType: NonFungibleFromJsonTokenType
    public var value: BigInt
    public var contractName: String
    public let decimals: Int
    public let symbol: String
    public let name: String
    public let description: String
    public let thumbnailUrl: String
    public let imageUrl: String
    public let animationUrl: String?
    public let previewUrl: String
    public var contractImageUrl: String
    public let imageOriginalUrl: String
    public let externalLink: String
    public let backgroundColor: String?
    public let traits: [OpenSeaNonFungibleTrait]
    public var generationTrait: OpenSeaNonFungibleTrait? {
        return traits.first { $0.type == NftAsset.generationTraitName }
    }
    public let collectionCreatedDate: Date?
    public var collectionDescription: String?
    public var collection: AlphaWalletOpenSea.NftCollection?

    public var creator: AssetCreator?
    public let collectionId: String

    public init(contract: AlphaWallet.Address, tokenId: String, tokenType: NonFungibleFromJsonTokenType, value: BigInt, contractName: String, decimals: Int, symbol: String, name: String, description: String, thumbnailUrl: String, imageUrl: String, contractImageUrl: String, externalLink: String, backgroundColor: String?, traits: [OpenSeaNonFungibleTrait], collectionCreatedDate: Date?, collectionDescription: String?, collection: AlphaWalletOpenSea.NftCollection? = nil, creator: AssetCreator?, collectionId: String, imageOriginalUrl: String, previewUrl: String, animationUrl: String?) {
        self.contract = contract
        self.imageOriginalUrl = imageOriginalUrl
        self.tokenId = tokenId
        self.tokenType = tokenType
        self.value = value
        self.contractName = contractName
        self.decimals = decimals
        self.symbol = symbol
        self.name = name
        self.description = description
        self.thumbnailUrl = thumbnailUrl
        self.imageUrl = imageUrl
        self.contractImageUrl = contractImageUrl
        self.externalLink = externalLink
        self.backgroundColor = backgroundColor
        self.traits = traits
        self.collectionCreatedDate = collectionCreatedDate
        self.collectionDescription = collectionDescription
        self.collection = collection
        self.creator = creator
        self.collectionId = collectionId
        self.previewUrl = previewUrl
        self.animationUrl = animationUrl
    }
}
