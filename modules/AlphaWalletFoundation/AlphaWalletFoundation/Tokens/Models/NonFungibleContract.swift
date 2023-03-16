// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine

final class NonFungibleContract {
    private let blockchainProvider: BlockchainProvider
    private let uriMapper: TokenUriMapSupportable

    public init(blockchainProvider: BlockchainProvider,
                uriMapper: TokenUriMapSupportable) {

        self.uriMapper = uriMapper
        self.blockchainProvider = blockchainProvider
    }

    func getUriOrTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> AnyPublisher<TokenUriData, SessionTaskError> {
        return blockchainProvider
            .call(Erc721TokenUriMethodCall(contract: contract, tokenId: tokenId))
            .catch { [blockchainProvider] _ -> AnyPublisher<TokenUriData, SessionTaskError> in
                return blockchainProvider
                    .call(Erc721UriMethodCall(contract: contract, tokenId: tokenId))
            }.map { [uriMapper] data -> TokenUriData in
                switch data {
                case .data, .json, .string:
                    return data
                case .uri(let uri):
                    return .uri(uriMapper.map(uri: uri) ?? uri)
                }
            }.eraseToAnyPublisher()
    }
}
