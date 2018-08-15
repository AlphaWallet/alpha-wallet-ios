// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct CryptoKitty: Codable {
    let tokenId: String
    let description: String
    let thumbnailUrl: String
    let imageUrl: String
    let externalLink: String
    let traits: [CryptoKittyTrait]
}

struct CryptoKittyTrait: Codable {
    let count: Int
    let type: String
    let value: String
}

struct CryptoKittyError: Error {
    var localizedDescription: String
}
