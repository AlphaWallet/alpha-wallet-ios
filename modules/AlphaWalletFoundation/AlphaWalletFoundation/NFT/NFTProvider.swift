//
//  NFTService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import Foundation
import AlphaWalletCore
import AlphaWalletOpenSea
import PromiseKit
import Combine

public typealias NonFungiblesTokens = (openSea: OpenSeaAddressesToNonFungibles, enjin: Void)

public protocol NFTProvider {
    func collectionStats(collectionId: String) -> Promise<Stats>
    func nonFungible() -> AnyPublisher<NonFungiblesTokens, Never>
    func enjinToken(tokenId: TokenId) -> EnjinToken?
}

extension OpenSea: NftAssetImageProvider {
    public func assetImageUrl(for url: Eip155URL) -> AnyPublisher<URL, AlphaWalletCore.PromiseError> {
        fetchAssetImageUrl(for: url).publisher(queue: .global())
    }
}

public final class AlphaWalletNFTProvider: NFTProvider {
    private let openSea: OpenSea
    private let enjin: Enjin
    private let wallet: Wallet
    private let server: RPCServer

    public init(analytics: AnalyticsLogger, wallet: Wallet, server: RPCServer, config: Config, storage: RealmStore) {
        self.wallet = wallet
        self.server = server
        enjin = Enjin(server: server, storage: storage)
        openSea = OpenSea(analytics: analytics, server: server, config: config)
    }

    private func getOpenSeaNonFungible() -> Promise<OpenSeaAddressesToNonFungibles> {
        return openSea.nonFungible(wallet: wallet)
    }

    public func collectionStats(collectionId: String) -> Promise<Stats> {
        openSea.collectionStats(collectionId: collectionId)
    }

    public func enjinToken(tokenId: TokenId) -> EnjinToken? {
        enjin.token(tokenId: tokenId)
    }

    public func nonFungible() -> AnyPublisher<NonFungiblesTokens, Never> {
        let key = AddressAndRPCServer(address: wallet.address, server: server)

        let tokensFromOpenSeaPromise = getOpenSeaNonFungible().publisher(queue: .global()).replaceError(with: [:])
        let enjinTokensPromise = enjin.fetchTokens(wallet: wallet).receive(on: DispatchQueue.global()).mapToVoid().replaceError(with: ())

        return Publishers.CombineLatest(tokensFromOpenSeaPromise, enjinTokensPromise)
            .map { ($0, $1) }
            .eraseToAnyPublisher()
    }

}
