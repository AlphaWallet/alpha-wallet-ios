//
//  NonFungibleFromJson.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation
import BigInt

//Shape of this originally created to match OpenSea's API output
public protocol NonFungibleFromJson: Codable {
    var tokenId: String { get }
    var tokenType: NonFungibleFromJsonTokenType { get }
    var value: BigInt { get set }
    var contractName: String { get }
    var decimals: Int { get }
    var symbol: String { get }
    var name: String { get }
    var description: String { get }
    var thumbnailUrl: String { get }
    var imageUrl: String { get }
    var contractImageUrl: String { get }
    var externalLink: String { get }
    var backgroundColor: String? { get }
    var traits: [OpenSeaNonFungibleTrait] { get }
    var generationTrait: OpenSeaNonFungibleTrait? { get }
    var collectionCreatedDate: Date? { get }
    var collectionDescription: String? { get }
    var meltStringValue: String? { get }
    var meltFeeRatio: Int? { get }
    var meltFeeMaxRatio: Int? { get }
    var totalSupplyStringValue: String? { get }
    var circulatingSupplyStringValue: String? { get }
    var reserveStringValue: String? { get }
    var nonFungible: Bool? { get }
    var blockHeight: Int? { get }
    var mintableSupply: BigInt? { get }
    var transferable: String? { get }
    var supplyModel: String? { get }
    var issuer: String? { get }
    var created: String? { get }
    var transferFee: String? { get }
    var slug: String { get }
    var creator: AssetCreator? { get }
    var collection: AlphaWalletOpenSea.Collection? { get }
}