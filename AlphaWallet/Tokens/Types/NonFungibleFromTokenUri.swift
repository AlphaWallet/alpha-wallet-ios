// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

//To store the output from ERC721's `tokenURI()`. The output has to be massaged to fit here as the properties was designed for OpenSea
struct NonFungibleFromTokenUri: Codable, NonFungibleFromJson {
    let tokenId: String
    let tokenType: NonFungibleFromJsonTokenType
    let contractName: String
    let decimals: Int
    let symbol: String
    let name: String
    var description: String {
        ""
    }
    let thumbnailUrl: String
    let imageUrl: String
    var contractImageUrl: String {
        ""
    }
    let externalLink: String
    var backgroundColor: String? {
        ""
    }
    var traits: [OpenSeaNonFungibleTrait] {
        .init()
    }
    var generationTrait: OpenSeaNonFungibleTrait? {
        nil
    }
}

struct NonFungibleFromTokenUriBeforeErc1155Support: Codable {
    let tokenId: String
    let contractName: String
    let symbol: String
    let name: String
    var description: String {
        ""
    }
    let thumbnailUrl: String
    let imageUrl: String
    var contractImageUrl: String {
        ""
    }
    let externalLink: String
    var backgroundColor: String? {
        ""
    }
    var traits: [OpenSeaNonFungibleTrait] {
        .init()
    }
    var generationTrait: OpenSeaNonFungibleTrait? {
        nil
    }

    var asPostErc1155Support: NonFungibleFromJson {
        let result = NonFungibleFromTokenUri(tokenId: tokenId, tokenType: .erc721, contractName: contractName, decimals: 0, symbol: symbol, name: name, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, externalLink: externalLink)
        return result
    }
}