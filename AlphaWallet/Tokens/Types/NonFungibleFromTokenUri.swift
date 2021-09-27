// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt

//To store the output from ERC721's `tokenURI()`. The output has to be massaged to fit here as the properties was designed for OpenSea
struct NonFungibleFromTokenUri: Codable, NonFungibleFromJson {
    let tokenId: String
    let tokenType: NonFungibleFromJsonTokenType
    var value: BigInt
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
    let collectionCreatedDate: Date?
    let collectionDescription: String?
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

    func asPostErc1155Support(tokenType: NonFungibleFromJsonTokenType?) -> NonFungibleFromJson {
        let result = NonFungibleFromTokenUri(tokenId: tokenId, tokenType: tokenType ?? .erc721, value: 1, contractName: contractName, decimals: 0, symbol: symbol, name: name, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, externalLink: externalLink, collectionCreatedDate: nil, collectionDescription: nil)
        return result
    }
}