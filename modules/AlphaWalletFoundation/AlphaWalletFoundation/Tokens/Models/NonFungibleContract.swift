// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletWeb3
import BigInt

final class NonFungibleContract {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getUriOrTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> AnyPublisher<TokenUriData, SessionTaskError> {
        return blockchainProvider
            .call(Erc721TokenUriMethodCall(contract: contract, tokenId: tokenId))
            .catch { [blockchainProvider] _ -> AnyPublisher<TokenUriData, SessionTaskError> in
                return blockchainProvider
                    .call(Erc721UriMethodCall(contract: contract, tokenId: tokenId))
            }.eraseToAnyPublisher()
    }
}
