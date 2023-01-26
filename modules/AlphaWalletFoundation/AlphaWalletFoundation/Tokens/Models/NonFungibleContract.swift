// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine

final class NonFungibleContract {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getUriOrTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> AnyPublisher<URL, SessionTaskError> {
        return getTokenUri(for: tokenId, contract: contract)
            .catch { _ -> AnyPublisher<URL, SessionTaskError> in
                self.getUri(for: tokenId, contract: contract)
            }.eraseToAnyPublisher()
    }

    private func getTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> AnyPublisher<URL, SessionTaskError> {
        blockchainProvider
            .call(Erc721TokenUriMethodCall(contract: contract, tokenId: tokenId))
    }

    private func getUri(for tokenId: String, contract: AlphaWallet.Address) -> AnyPublisher<URL, SessionTaskError> {
        blockchainProvider
            .call(Erc721UriMethodCall(contract: contract, tokenId: tokenId))
    }
}
