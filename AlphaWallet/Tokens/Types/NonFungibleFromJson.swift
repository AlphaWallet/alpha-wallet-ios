// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt

//Shape of this originally created to match OpenSea's API output
protocol NonFungibleFromJson: Codable {
    var tokenId: String { get }
    var tokenType: NonFungibleFromJsonTokenType { get }
    var value: BigInt { get set }
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
    var collectionCreatedDate: Date? { get }
    var collectionDescription: String? { get }
    var meltStringValue: String? { get }
    var meltFeeRatio: Int? { get }
    var meltFeeMaxRatio: Int? { get }
    var totalSupplyStringValue: String? { get }
    var circulatingSupplyStringValue: String? { get }
    var reserveStringValue: String? { get }
    var nonFungible: Bool? { get }
    var blockHeight: Int? { get }
    var mintableSupply: BigInt? { get }
    var transferable: String? { get }
    var supplyModel: String? { get }
    var issuer: String? { get }
    var created: String? { get }
    var transferFee: String? { get }
}

func nonFungible(fromJsonData jsonData: Data, tokenType: TokenType? = nil) -> NonFungibleFromJson? {
    if let nonFungible = try? JSONDecoder().decode(OpenSeaNonFungible.self, from: jsonData) {
        return nonFungible
    }
    if let nonFungible = try? JSONDecoder().decode(NonFungibleFromTokenUri.self, from: jsonData) {
        return nonFungible
    }

    let nonFungibleTokenType = tokenType.flatMap { TokensDataStore.functional.nonFungibleTokenType(fromTokenType: $0) }
    //Parse JSON strings which were saved before we added support for ERC1155. So they are might be ERC721s with missing fields
    if let nonFungible = try? JSONDecoder().decode(OpenSeaNonFungibleBeforeErc1155Support.self, from: jsonData) {
        return nonFungible.asPostErc1155Support(tokenType: nonFungibleTokenType)
    }
    if let nonFungible = try? JSONDecoder().decode(NonFungibleFromTokenUriBeforeErc1155Support.self, from: jsonData) {
        return nonFungible.asPostErc1155Support(tokenType: nonFungibleTokenType)
    }

    return nil
}
