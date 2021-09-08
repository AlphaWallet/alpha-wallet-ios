// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

//Shape of this originally created to match OpenSea's API output
protocol NonFungibleFromJson: Codable {
    var tokenId: String { get }
    var tokenType: NonFungibleFromJsonTokenType { get }
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
}

func nonFungible(fromJsonData jsonData: Data) -> NonFungibleFromJson? {
    if let nonFungible = try? JSONDecoder().decode(OpenSeaNonFungible.self, from: jsonData) {
        return nonFungible
    }
    if let nonFungible = try? JSONDecoder().decode(NonFungibleFromTokenUri.self, from: jsonData) {
        return nonFungible
    }

    //Parse JSON strings which were saved before we added support for ERC1155. So they are all ERC721s with missing fields
    if let nonFungible = try? JSONDecoder().decode(OpenSeaNonFungibleBeforeErc1155Support.self, from: jsonData) {
        return nonFungible.asPostErc1155Support
    }
    if let nonFungible = try? JSONDecoder().decode(NonFungibleFromTokenUriBeforeErc1155Support.self, from: jsonData) {
        return nonFungible.asPostErc1155Support
    }

    return nil
}