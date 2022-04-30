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

    private let openSea = OpenSea()
    private let enjin = Enjin()

    // NOTE: Its important to return value for promise and not an error. As we are using `when(fulfilled: ...)`. There is force unwrap inside the `when(fulfilled` function
    private func getEnjinSemiFungible(account: Wallet, server: RPCServer) -> Promise<EnjinSemiFungiblesToTokenId> {
        return enjin.semiFungible(wallet: account, server: server)
            .map({ mapped -> EnjinSemiFungiblesToTokenId in
                var result: EnjinSemiFungiblesToTokenId = [:]
                let tokens = Array(mapped.values.flatMap { $0 })
                for each in tokens {
                    guard let tokenId = each.id else { continue }
                    // NOTE: store with trailing zeros `70000000000019a4000000000000000000000000000000000000000000000000` instead of `70000000000019a4`
                    result[TokenIdConverter.addTrailingZerosPadding(string: tokenId)] = each
                }
                return result
            }).recover { _ -> Promise<EnjinSemiFungiblesToTokenId> in
                return .value([:])
            }
    }

    private func getOpenSeaNonFungible(account: Wallet, server: RPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        return openSea.nonFungible(wallet: account, server: server)
    }

    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<NonFungiblesTokens> {
        let tokensFromOpenSeaPromise = getOpenSeaNonFungible(account: wallet, server: server)
        let enjinTokensPromise = getEnjinSemiFungible(account: wallet, server: server)

        return firstly {
            when(fulfilled: tokensFromOpenSeaPromise, enjinTokensPromise)
        }.map { (contractToOpenSeaNonFungibles, enjinTokens) -> NonFungiblesTokens in
            return (contractToOpenSeaNonFungibles, enjinTokens)
        }
    }

}
