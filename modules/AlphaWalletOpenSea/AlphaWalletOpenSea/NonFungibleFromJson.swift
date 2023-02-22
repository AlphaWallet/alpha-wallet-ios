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
    var symbol: String { get }
    var name: String { get }
    var description: String { get }
    var thumbnailUrl: String { get }
    var imageUrl: String { get }
    var animationUrl: String? { get }
    var contractImageUrl: String { get }
    var externalLink: String { get }
    var backgroundColor: String? { get }
    var traits: [OpenSeaNonFungibleTrait] { get }
    var generationTrait: OpenSeaNonFungibleTrait? { get }
    var collectionCreatedDate: Date? { get }
    var collectionDescription: String? { get }
    var collectionId: String { get }
    var creator: AssetCreator? { get }
    var collection: AlphaWalletOpenSea.NftCollection? { get }
}
