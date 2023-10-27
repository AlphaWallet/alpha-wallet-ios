// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import AlphaWalletCore
import AlphaWalletOpenSea

extension NonFungibleFromJson {
    public func nftCollectionImageUrl(rewriteGoogleContentSizeUrl size: GoogleContentSize) -> WebImageURL? {
        return WebImageURL(string: contractImageUrl, rewriteGoogleContentSizeUrl: size) ??
        WebImageURL(string: thumbnailUrl, rewriteGoogleContentSizeUrl: size) ??
        animationUrl.flatMap { WebImageURL(string: $0, rewriteGoogleContentSizeUrl: size) } ??
        WebImageURL(string: imageUrl, rewriteGoogleContentSizeUrl: size)
    }
}

public func nonFungible(fromJsonData jsonData: Data, tokenType: TokenType? = nil, decoder: JSONDecoder = JSONDecoder()) -> NonFungibleFromJson? {
    if let nonFungible = try? decoder.decode(NftAsset.self, from: jsonData) {
        return nonFungible
    }
    if let nonFungible = try? decoder.decode(NonFungibleFromTokenUri.self, from: jsonData) {
        return nonFungible
    }

    let nonFungibleTokenType = tokenType.flatMap { MultipleChainsTokensDataStore.functional.nonFungibleTokenType(fromTokenType: $0) }
    //Parse JSON strings which were saved before we added support for ERC1155. So they are might be ERC721s with missing fields
    if let nonFungible = try? decoder.decode(OpenSeaNonFungibleBeforeErc1155Support.self, from: jsonData) {
        return nonFungible.asPostErc1155Support(tokenType: nonFungibleTokenType)
    }
    if let nonFungible = try? decoder.decode(NonFungibleFromTokenUriBeforeErc1155Support.self, from: jsonData) {
        return nonFungible.asPostErc1155Support(tokenType: nonFungibleTokenType)
    }

    return nil
}
