//
//  FakeNftProvider.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import PromiseKit
import AlphaWalletCore
import AlphaWalletFoundation
import Combine

final class FakeNftProvider: NFTProvider, NftAssetImageProvider {
    func assetImageUrl(for url: Eip155URL) -> AnyPublisher<URL, PromiseError> {
        return .fail(PromiseError.some(error: ProviderError()))
    }

    struct ProviderError: Error {}

    func collectionStats(collectionId: String) -> Promise<Stats> {
        return .init(error: ProviderError())
    }
    func nonFungible() -> AnyPublisher<NonFungiblesTokens, Never> {
        return .just((openSea: [:], enjin: ()))
    }
    
    func enjinToken(tokenId: TokenId) -> EnjinToken? {
        return nil
    }
}
