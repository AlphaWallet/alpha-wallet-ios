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

    private lazy var openSea = OpenSea()
    private lazy var enjin = Enjin()
    private var cachedPromises: AtomicDictionary<AddressAndRPCServer, Promise<NonFungiblesTokens>> = .init()

    // NOTE: Its important to return value for promise and not an error. As we are using `when(fulfilled: ...)`. There is force unwrap inside the `when(fulfilled` function
    private func getEnjinSemiFungible(account: Wallet, server: RPCServer) -> Promise<EnjinSemiFungiblesToTokenId> {
        return enjin.semiFungible(wallet: account, server: server)
            .map(on: .none, { mapped -> EnjinSemiFungiblesToTokenId in
                var result: EnjinSemiFungiblesToTokenId = [:]
                let tokens = Array(mapped.values.flatMap { $0 })
                for each in tokens {
                    guard let tokenId = each.id else { continue }
                    // NOTE: store with trailing zeros `70000000000019a4000000000000000000000000000000000000000000000000` instead of `70000000000019a4`
                    result[TokenIdConverter.addTrailingZerosPadding(string: tokenId)] = each
                }
                return result
            }).recover(on: .none, { _ -> Promise<EnjinSemiFungiblesToTokenId> in
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
            }.map(on: .none, { (contractToOpenSeaNonFungibles, enjinTokens) -> NonFungiblesTokens in
                return (contractToOpenSeaNonFungibles, enjinTokens)
            }).ensure(on: .none, {
                self.cachedPromises[key] = .none
            })

            cachedPromises[key] = promise

            return promise
        }
    }

}
