// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletOpenSea
import BigInt
import SwiftyJSON

extension NftAsset {
    var tokenIdSubstituted: String {
        return TokenIdConverter.toTokenIdSubstituted(string: tokenId)
    }
}

struct TokenIdConverter {
    static func toTokenIdSubstituted(string: String) -> String {
        if let tokenId = BigInt(string) {
            let string = String(tokenId, radix: 16)
            return TokenIdConverter.addTrailingZerosPadding(string: string)
        } else {
            return string
        }
    }

    static func addTrailingZerosPadding(string: String) -> String {
        return string.padding(toLength: 64, withPad: "0", startingAt: 0)
    }
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
    let animationUrl: String?
    let traits: [OpenSeaNonFungibleTrait]
    var generationTrait: OpenSeaNonFungibleTrait? {
        return traits.first { $0.type == NftAsset.generationTraitName }
    }

    func asPostErc1155Support(tokenType: NonFungibleFromJsonTokenType?) -> NonFungibleFromJson {
        //TODO probably not the best to use Constants.nullAddress
        let result = NftAsset(contract: Constants.nullAddress, tokenId: tokenId, tokenType: tokenType ?? .erc721, value: 1, contractName: contractName, decimals: 0, symbol: symbol, name: name, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, contractImageUrl: contractImageUrl, externalLink: externalLink, backgroundColor: backgroundColor, traits: traits, collectionCreatedDate: nil, collectionDescription: nil, creator: nil, collectionId: "", imageOriginalUrl: "", previewUrl: "", animationUrl: animationUrl)
        return result
    }
}
