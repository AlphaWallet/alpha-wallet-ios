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

public typealias NonFungiblesTokens = (openSea: OpenSeaAddressesToNonFungibles, enjin: EnjinTokenIdsToSemiFungibles)

public protocol NFTProvider {
    func collectionStats(collectionId: String) -> Promise<Stats>
    func nonFungible() -> Promise<NonFungiblesTokens>
}

extension OpenSea: NftAssetImageProvider {
    public func assetImageUrl(for url: Eip155URL) -> AnyPublisher<URL, AlphaWalletCore.PromiseError> {
        fetchAssetImageUrl(for: url).publisher(queue: .global())
    }
}

public final class AlphaWalletNFTProvider: NFTProvider {
    private let openSea: OpenSea
    private let enjin: Enjin
    private var inflightPromises: AtomicDictionary<AddressAndRPCServer, Promise<NonFungiblesTokens>> = .init()
    //TODO when we remove `queue`, it's also a good time to look at using a shared copy of `OpenSea` from `AppCoordinator`
    private let queue = DispatchQueue(label: "org.alphawallet.swift.nftProvider")
    private let wallet: Wallet
    private let server: RPCServer

    public init(analytics: AnalyticsLogger, wallet: Wallet, server: RPCServer, config: Config) {
        self.wallet = wallet
        self.server = server
        enjin = Enjin(server: server)
        openSea = OpenSea(analytics: analytics, server: server, config: config)
    }

    // NOTE: Its important to return value for promise and not an error. As we are using `when(fulfilled: ...)`. There is force unwrap inside the `when(fulfilled` function
    private func getEnjinSemiFungible() -> Promise<EnjinTokenIdsToSemiFungibles> {
        return enjin.semiFungible(wallet: wallet)
            .map(on: queue, { mapped -> EnjinTokenIdsToSemiFungibles in
                var result: EnjinTokenIdsToSemiFungibles = [:]
                let tokens = Array(mapped.values.flatMap { $0 })
                for each in tokens {
                    guard let tokenId = each.id else { continue }
                    // NOTE: store with trailing zeros `70000000000019a4000000000000000000000000000000000000000000000000` instead of `70000000000019a4`
                    result[TokenIdConverter.addTrailingZerosPadding(string: tokenId)] = each
                }
                return result
            }).recover(on: queue, { _ -> Promise<EnjinTokenIdsToSemiFungibles> in
                return .value([:])
            })
    }

    private func getOpenSeaNonFungible() -> Promise<OpenSeaAddressesToNonFungibles> {
        return openSea.nonFungible(wallet: wallet)
    }

    public func collectionStats(collectionId: String) -> Promise<Stats> {
        openSea.collectionStats(collectionId: collectionId)
    }

    public func nonFungible() -> Promise<NonFungiblesTokens> {
        let key = AddressAndRPCServer(address: wallet.address, server: server)

        if let promise = inflightPromises[key] {
            return promise
        } else {
            let tokensFromOpenSeaPromise = getOpenSeaNonFungible()
            let enjinTokensPromise = getEnjinSemiFungible()

            let promise = firstly {
                when(fulfilled: tokensFromOpenSeaPromise, enjinTokensPromise)
            }.map(on: queue, { (contractToOpenSeaNonFungibles, enjinTokens) -> NonFungiblesTokens in
                return (contractToOpenSeaNonFungibles, enjinTokens)
            }).ensure(on: queue, {
                self.inflightPromises[key] = .none
            })

            inflightPromises[key] = promise

            return promise
        }
    }

}
