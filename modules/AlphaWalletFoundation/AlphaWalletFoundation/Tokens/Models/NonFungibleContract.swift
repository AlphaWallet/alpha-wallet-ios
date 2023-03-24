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

    func getUriOrTokenUri(for tokenId: String, contract: AlphaWallet.Address) async throws -> TokenUriData {
        let data: Erc721TokenUriMethodCall.Response
        do {
            data = try await blockchainProvider.call(Erc721TokenUriMethodCall(contract: contract, tokenId: tokenId))
        } catch {
            data = try await blockchainProvider.call(Erc721UriMethodCall(contract: contract, tokenId: tokenId))
        }

        switch data {
        case .data, .json, .string:
            return data
        case .uri(let uri):
            return .uri(uriMapper.map(uri: uri) ?? uri)
        }
    }
}
