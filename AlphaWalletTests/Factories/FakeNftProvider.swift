//
//  FakeNftProvider.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import PromiseKit
import AlphaWalletFoundation

class FakeNftProvider: NFTProvider {
    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<NonFungiblesTokens> {
        return .value((openSea: [:], enjin: [:]))
    }
}
