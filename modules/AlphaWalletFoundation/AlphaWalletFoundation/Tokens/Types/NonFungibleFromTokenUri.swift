// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletOpenSea
import BigInt

//To store the output from ERC721's `tokenURI()`. The output has to be massaged to fit here as the properties was designed for OpenSea
public struct NonFungibleFromTokenUri: Codable, NonFungibleFromJson {
    public var slug: String {
        ""
    }

    public var creator: AssetCreator? {
        return nil
    }

    public var collection: AlphaWalletOpenSea.Collection? {
        return nil
    }

    public let tokenId: String
    public let tokenType: NonFungibleFromJsonTokenType
    public var value: BigInt
    public let contractName: String
    public let decimals: Int
    public let symbol: String
    public let name: String
    public var description: String {
        ""
    }
    public let thumbnailUrl: String
    public let imageUrl: String
    public var contractImageUrl: String {
        ""
    }
    public let externalLink: String
    public var backgroundColor: String? {
        ""
    }
    public var traits: [OpenSeaNonFungibleTrait] {
        .init()
    }
    public var generationTrait: OpenSeaNonFungibleTrait? {
        nil
    }
    public let collectionCreatedDate: Date?
    public let collectionDescription: String?
    public var meltStringValue: String?
    public var meltFeeRatio: Int?
    public var meltFeeMaxRatio: Int?
    public var totalSupplyStringValue: String?
    public var circulatingSupplyStringValue: String?
    public var reserveStringValue: String?
    public var nonFungible: Bool?
    public var blockHeight: Int?
    public var mintableSupply: BigInt?
    public var transferable: String?
    public var supplyModel: String?
    public var issuer: String?
    public var created: String?
    public var transferFee: String?
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

    let collectionCreatedDate: Date?
    let collectionDescription: String?
    var meltStringValue: String?
    var meltFeeRatio: Int?
    var meltFeeMaxRatio: Int?
    var totalSupplyStringValue: String?
    var circulatingSupplyStringValue: String?
    var reserveStringValue: String?
    var nonFungible: Bool?
    var blockHeight: Int?
    var mintableSupply: BigInt?
    var issuer: String?
    var created: String?
    var transferFee: String?

    func asPostErc1155Support(tokenType: NonFungibleFromJsonTokenType?) -> NonFungibleFromJson {
        let result = NonFungibleFromTokenUri(tokenId: tokenId, tokenType: tokenType ?? .erc721, value: 1, contractName: contractName, decimals: 0, symbol: symbol, name: name, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, externalLink: externalLink, collectionCreatedDate: collectionCreatedDate, collectionDescription: collectionDescription, meltStringValue: meltStringValue, meltFeeRatio: meltFeeRatio, meltFeeMaxRatio: meltFeeMaxRatio, totalSupplyStringValue: totalSupplyStringValue, circulatingSupplyStringValue: circulatingSupplyStringValue, reserveStringValue: reserveStringValue, nonFungible: nonFungible, blockHeight: blockHeight, mintableSupply: mintableSupply, issuer: issuer, created: created, transferFee: transferFee)
        return result
    }
}
