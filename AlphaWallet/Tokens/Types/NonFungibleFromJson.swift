// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

//Shape of this originally created to match OpenSea's API output
protocol NonFungibleFromJson: Codable {
    var tokenId: String { get }
    var contractName: String { get }
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
}

func nonFungible(fromJsonData jsonData: Data) -> NonFungibleFromJson? {
    if let nonFungible = try? JSONDecoder().decode(OpenSeaNonFungible.self, from: jsonData) {
        return nonFungible
    }
    if let nonFungible = try? JSONDecoder().decode(NonFungibleFromTokenUri.self, from: jsonData) {
        return nonFungible
    }
    return nil
}