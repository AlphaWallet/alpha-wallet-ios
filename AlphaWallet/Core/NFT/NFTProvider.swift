//
//  NFTService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import Foundation
import AlphaWalletOpenSea
import PromiseKit

typealias NonFungiblesTokens = (openSea: OpenSeaNonFungiblesToAddress, enjin: EnjinSemiFungiblesToTokenId)

protocol NFTProvider: AnyObject {
    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<NonFungiblesTokens>
}

final class AlphaWalletNFTProvider: NFTProvider {

    private let analyticsCoordinator: AnalyticsCoordinator
    private lazy var openSea = OpenSea(analyticsCoordinator: analyticsCoordinator, queue: queue)
    private lazy var enjin = Enjin(queue: queue)
    private var cachedPromises: AtomicDictionary<AddressAndRPCServer, Promise<NonFungiblesTokens>> = .init()
    //TODO when we remove `queue`, it's also a good time to look at using a shared copy of `OpenSea` from `AppCoordinator`
    private let queue: DispatchQueue

    init(analyticsCoordinator: AnalyticsCoordinator, queue: DispatchQueue) {
        self.analyticsCoordinator = analyticsCoordinator
        self.queue = queue
    }

    // NOTE: Its important to return value for promise and not an error. As we are using `when(fulfilled: ...)`. There is force unwrap inside the `when(fulfilled` function
    private func getEnjinSemiFungible(account: Wallet, server: RPCServer) -> Promise<EnjinSemiFungiblesToTokenId> {
        return enjin.semiFungible(wallet: account, server: server)
            .map(on: queue, { mapped -> EnjinSemiFungiblesToTokenId in
                var result: EnjinSemiFungiblesToTokenId = [:]
                let tokens = Array(mapped.values.flatMap { $0 })
                for each in tokens {
                    guard let tokenId = each.id else { continue }
                    // NOTE: store with trailing zeros `70000000000019a4000000000000000000000000000000000000000000000000` instead of `70000000000019a4`
                    result[TokenIdConverter.addTrailingZerosPadding(string: tokenId)] = each
                }
                return result
            }).recover(on: queue, { _ -> Promise<EnjinSemiFungiblesToTokenId> in
                return .value([:])
            })
    }

    private func getOpenSeaNonFungible(account: Wallet, server: RPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        return openSea.nonFungible(wallet: account, server: server)
    }

    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<NonFungiblesTokens> {
        let key = AddressAndRPCServer(address: wallet.address, server: server)

        if let promise = cachedPromises[key] {
            return promise
        } else {
            let tokensFromOpenSeaPromise = getOpenSeaNonFungible(account: wallet, server: server)
            let enjinTokensPromise = getEnjinSemiFungible(account: wallet, server: server)

            let promise = firstly {
                when(fulfilled: tokensFromOpenSeaPromise, enjinTokensPromise)
            }.map(on: queue, { (contractToOpenSeaNonFungibles, enjinTokens) -> NonFungiblesTokens in
                return (contractToOpenSeaNonFungibles, enjinTokens)
            }).ensure(on: queue, {
                self.cachedPromises[key] = .none
            })

            cachedPromises[key] = promise

            return promise
        }
    }

}
