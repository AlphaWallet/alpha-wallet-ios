//
//  OpenSeaNonFungible.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import BigInt

//Some fields are duplicated across token IDs within the same contract like the contractName, symbol, contractImageUrl, etc. The space savings in the database aren't work the normalization
public struct OpenSeaNonFungible: Codable, Equatable, Hashable, NonFungibleFromJson {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(tokenId)
        hasher.combine(tokenType.rawValue)
        hasher.combine(value.description)
    }

    public static func == (lhs: OpenSeaNonFungible, rhs: OpenSeaNonFungible) -> Bool {
        return lhs.tokenId == rhs.tokenId
    }

    //Not every token might used the same name. This is just common in OpenSea
    public static let generationTraitName = "generation"
    static let cooldownIndexTraitName = "cooldown_index"

    public let tokenId: String
    public let tokenType: NonFungibleFromJsonTokenType
    public var value: BigInt
    public let contractName: String
    public let decimals: Int
    public let symbol: String
    public let name: String
    public let description: String
    public let thumbnailUrl: String
    public let imageUrl: String
    public let contractImageUrl: String
    public let externalLink: String
    public let backgroundColor: String?
    public let traits: [OpenSeaNonFungibleTrait]
    public var generationTrait: OpenSeaNonFungibleTrait? {
        return traits.first { $0.type == OpenSeaNonFungible.generationTraitName }
    }
    public let collectionCreatedDate: Date?
    public let collectionDescription: String?
    public var meltStringValue: String?
    public var meltFeeRatio: Int?
    public var meltFeeMaxRatio: Int?
    public var totalSupplyStringValue: String?
    public var circulatingSupplyStringValue: String?
    public var reserveStringValue: String?
    public var nonFungible: Bool?
    public var blockHeight: Int?
    public var mintableSupply: BigInt?
    public var transferable: String?
    public var supplyModel: String?
    public var issuer: String?
    public var created: String?
    public var transferFee: String?
    public var collection: AlphaWalletOpenSea.Collection?
    public var creator: AssetCreator?
    public let slug: String

    //TODO remove when we aren't calling from outside the pod
    public init(tokenId: String, tokenType: NonFungibleFromJsonTokenType, value: BigInt, contractName: String, decimals: Int, symbol: String, name: String, description: String, thumbnailUrl: String, imageUrl: String, contractImageUrl: String, externalLink: String, backgroundColor: String?, traits: [OpenSeaNonFungibleTrait], collectionCreatedDate: Date?, collectionDescription: String?, meltStringValue: String? = nil, meltFeeRatio: Int? = nil, meltFeeMaxRatio: Int? = nil, totalSupplyStringValue: String? = nil, circulatingSupplyStringValue: String? = nil, reserveStringValue: String? = nil, nonFungible: Bool? = nil, blockHeight: Int? = nil, mintableSupply: BigInt? = nil, transferable: String? = nil, supplyModel: String? = nil, issuer: String? = nil, created: String? = nil, transferFee: String? = nil, collection: AlphaWalletOpenSea.Collection? = nil, creator: AssetCreator?, slug: String) {
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
        self.meltStringValue = meltStringValue
        self.meltFeeRatio = meltFeeRatio
        self.meltFeeMaxRatio = meltFeeMaxRatio
        self.totalSupplyStringValue = totalSupplyStringValue
        self.circulatingSupplyStringValue = circulatingSupplyStringValue
        self.reserveStringValue = reserveStringValue
        self.nonFungible = nonFungible
        self.blockHeight = blockHeight
        self.mintableSupply = mintableSupply
        self.transferable = transferable
        self.supplyModel = supplyModel
        self.issuer = issuer
        self.created = created
        self.transferFee = transferFee
        self.collection = collection
        self.creator = creator
        self.slug = slug
    }
}