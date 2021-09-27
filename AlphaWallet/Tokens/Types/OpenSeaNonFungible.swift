// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt

//Some fields are duplicated across token IDs within the same contract like the contractName, symbol, contractImageUrl, etc. The space savings in the database aren't work the normalization
struct OpenSeaNonFungible: Codable, NonFungibleFromJson {
    //Not every token might used the same name. This is just common in OpenSea
    public static let generationTraitName = "generation"
    public static let cooldownIndexTraitName = "cooldown_index"

    let tokenId: String
    let tokenType: NonFungibleFromJsonTokenType
    var value: BigInt
    let contractName: String
    let decimals: Int
    let symbol: String
    let name: String
    let description: String
    let thumbnailUrl: String
    let imageUrl: String
    let contractImageUrl: String
    let externalLink: String
    let backgroundColor: String?
    let traits: [OpenSeaNonFungibleTrait]
    var generationTrait: OpenSeaNonFungibleTrait? {
        return traits.first { $0.type == OpenSeaNonFungible.generationTraitName }
    }
    let collectionCreatedDate: Date?
    let collectionDescription: String?
}

struct OpenSeaNonFungibleTrait: Codable {
    let count: Int
    let type: String
    let value: String
}

struct OpenSeaError: Error {
    var localizedDescription: String
}

struct OpenSeaNonFungibleBeforeErc1155Support: Codable {
    //Not every token might used the same name. This is just common in OpenSea
    public static let generationTraitName = "generation"
    public static let cooldownIndexTraitName = "cooldown_index"

    let tokenId: String
    let contractName: String
    let symbol: String
    let name: String
    let description: String
    let thumbnailUrl: String
    let imageUrl: String
    let contractImageUrl: String
    let externalLink: String
    let backgroundColor: String?
    let traits: [OpenSeaNonFungibleTrait]
    var generationTrait: OpenSeaNonFungibleTrait? {
        return traits.first { $0.type == OpenSeaNonFungible.generationTraitName }
    }

    func asPostErc1155Support(tokenType: NonFungibleFromJsonTokenType?) -> NonFungibleFromJson {
        let result = OpenSeaNonFungible(tokenId: tokenId, tokenType: tokenType ?? .erc721, value: 1, contractName: contractName, decimals: 0, symbol: symbol, name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, contractImageUrl: contractImageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits, collectionCreatedDate: nil, collectionDescription: nil)
        return result
    }
}
