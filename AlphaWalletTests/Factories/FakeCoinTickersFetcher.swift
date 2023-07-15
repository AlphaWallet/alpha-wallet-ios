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

extension CoinTickers {
    static func make(config: Config = .make()) -> CoinTickersProvider & CoinTickersFetcher {
        return CoinTickers(fetchers: [], storage: RealmStore(realm: fakeRealm()))
    }
}
