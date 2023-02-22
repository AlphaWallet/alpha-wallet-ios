// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletOpenSea
import BigInt

//To store the output from ERC721's `tokenURI()`. The output has to be massaged to fit here as the properties was designed for OpenSea
public struct NonFungibleFromTokenUri: Codable, NonFungibleFromJson {
    public var collectionId: String { "" }
    public var creator: AssetCreator? { return nil }
    public var collection: AlphaWalletOpenSea.NftCollection? { return nil }
    public let tokenId: String
    public let tokenType: NonFungibleFromJsonTokenType
    public var value: BigInt
    public let contractName: String
    public let symbol: String
    public let name: String
    public var description: String { "" }
    public let thumbnailUrl: String
    public let imageUrl: String
    public let animationUrl: String?
    public var contractImageUrl: String { "" }
    public let externalLink: String
    public var backgroundColor: String? { "" }
    public var traits: [OpenSeaNonFungibleTrait] { [] }
    public var generationTrait: OpenSeaNonFungibleTrait? { nil }
    public let collectionCreatedDate: Date?
    public let collectionDescription: String?
}

struct NonFungibleFromTokenUriBeforeErc1155Support: Codable {
    let tokenId: String
    let contractName: String
    let symbol: String
    let name: String
    var description: String { "" }
    let thumbnailUrl: String
    let imageUrl: String
    var contractImageUrl: String { "" }
    let externalLink: String
    var backgroundColor: String? { "" }
    let animationUrl: String?
    var traits: [OpenSeaNonFungibleTrait] { [] }
    var generationTrait: OpenSeaNonFungibleTrait? { nil }
    let collectionCreatedDate: Date?
    let collectionDescription: String?

    func asPostErc1155Support(tokenType: NonFungibleFromJsonTokenType?) -> NonFungibleFromJson {
        let result = NonFungibleFromTokenUri(tokenId: tokenId, tokenType: tokenType ?? .erc721, value: 1, contractName: contractName/*, decimals: 0*/, symbol: symbol, name: name, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, animationUrl: animationUrl, externalLink: externalLink, collectionCreatedDate: collectionCreatedDate, collectionDescription: collectionDescription)
        return result
    }
}
