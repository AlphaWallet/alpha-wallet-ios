//
//  FakeCoinTickersFetcher.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 19.07.2022.
//

import XCTest
import Combine
@testable import AlphaWallet
import AlphaWalletCore
import AlphaWalletFoundation

extension CoinTickersFetcherImpl {
    static func make(config: Config = .make()) -> CoinTickersFetcher {
        return CoinTickersFetcherImpl(providers: [], storage: RealmStore(realm: fakeRealm()))
    }
}
