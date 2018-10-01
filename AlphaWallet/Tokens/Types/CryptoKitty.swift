// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct CryptoKitty: Codable {
    public static let generationTraitName = "generation"
    public static let cooldownIndexTraitName = "cooldown_index"

    let tokenId: String
    let description: String
    let thumbnailUrl: String
    let imageUrl: String
    let externalLink: String
    let backgroundColor: String?
    let traits: [CryptoKittyTrait]
    var generationTrait: CryptoKittyTrait? {
        return traits.first(where: { $0.type == CryptoKitty.generationTraitName  })
    }
}

struct CryptoKittyTrait: Codable {
    let count: Int
    let type: String
    let value: String
}

struct CryptoKittyError: Error {
    var localizedDescription: String
}
