//
//  FakeNftProvider.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import AlphaWalletCore
import AlphaWalletFoundation
import Combine

final class FakeNftProvider: NFTProvider, NftAssetImageProvider {
    func assetImageUrl(contract: AlphaWallet.Address, id: BigUInt) async throws -> URL {
        throw ProviderError()
    }

    struct ProviderError: Error {}

    func collectionStats(collectionId: String) -> AnyPublisher<Stats, PromiseError> {
        return .fail(PromiseError(error: ProviderError()))
    }

    func nonFungible() -> AnyPublisher<NonFungiblesTokens, Never> {
        return .just((openSea: [:], enjin: ()))
    }

    func enjinToken(tokenId: TokenId) -> EnjinToken? {
        return nil
    }
}
