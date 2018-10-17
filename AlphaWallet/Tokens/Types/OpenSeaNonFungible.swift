// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct OpenSeaNonFungible: Codable {
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
    let externalLink: String
    let backgroundColor: String?
    let traits: [OpenSeaNonFungibleTrait]
    var generationTrait: OpenSeaNonFungibleTrait? {
        return traits.first(where: { $0.type == OpenSeaNonFungible.generationTraitName  })
    }
}

struct OpenSeaNonFungibleTrait: Codable {
    let count: Int
    let type: String
    let value: String
}

struct OpenSeaError: Error {
    var localizedDescription: String
}
