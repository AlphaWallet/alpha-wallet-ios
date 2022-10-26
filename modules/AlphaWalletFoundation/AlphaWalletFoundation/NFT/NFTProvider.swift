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

public protocol NFTProvider: NftAssetImageProvider {
    func collectionStats(slug: String, server: RPCServer) -> Promise<Stats>
    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<NonFungiblesTokens>
}

public final class AlphaWalletNFTProvider: NFTProvider {
    private let openSea: OpenSea
    private let enjin: Enjin
    private var inflightPromises: AtomicDictionary<AddressAndRPCServer, Promise<NonFungiblesTokens>> = .init()
    //TODO when we remove `queue`, it's also a good time to look at using a shared copy of `OpenSea` from `AppCoordinator`
    private let queue = DispatchQueue(label: "org.alphawallet.swift.nftProvider")

    public init(analytics: AnalyticsLogger) {
        enjin = Enjin()
        openSea = OpenSea(analytics: analytics)
    }

    // NOTE: Its important to return value for promise and not an error. As we are using `when(fulfilled: ...)`. There is force unwrap inside the `when(fulfilled` function
    private func getEnjinSemiFungible(account: Wallet, server: RPCServer) -> Promise<EnjinTokenIdsToSemiFungibles> {
        return enjin.semiFungible(wallet: account, server: server)
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

    private func getOpenSeaNonFungible(account: Wallet, server: RPCServer) -> Promise<OpenSeaAddressesToNonFungibles> {
        return openSea.nonFungible(wallet: account, server: server)
    }

    public func assetImageUrl(for url: Eip155URL) -> AnyPublisher<URL, PromiseError> {
        openSea.fetchAssetImageUrl(for: url, server: .main).publisher
    }

    public func collectionStats(slug: String, server: RPCServer) -> Promise<Stats> {
        openSea.collectionStats(slug: slug, server: server)
    }

    public func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<NonFungiblesTokens> {
        let key = AddressAndRPCServer(address: wallet.address, server: server)

        if let promise = inflightPromises[key] {
            return promise
        } else {
            let tokensFromOpenSeaPromise = getOpenSeaNonFungible(account: wallet, server: server)
            let enjinTokensPromise = getEnjinSemiFungible(account: wallet, server: server)

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
