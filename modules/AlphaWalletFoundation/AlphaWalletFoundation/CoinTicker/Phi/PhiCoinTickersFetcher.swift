//
//  PhiCoinTickersFetcher.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 16.09.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public final class PhiCoinTickersFetcher: BaseCoinTickersFetcher, CoinTickersFetcherProvider {

    public convenience init(storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage) {
        let networkProvider: CoinTickerNetworkProviderType
        if isRunningTests() {
            networkProvider = FakeCoinGeckoNetworkProvider()
        } else {
            networkProvider = PhiNetworkProvider()
        }

        let tickerIdsFetcher: TickerIdsFetcher = TickerIdsFetcherImpl(providers: [
            PhiTickerIdsFetcher(),
        ])

        self.init(networkProvider: networkProvider, storage: storage, tickerIdsFetcher: tickerIdsFetcher)
    }

    private class PhiTickerIdsFetcher: TickerIdsFetcher {
        /// Returns already defined, stored associated with token ticker id
        public func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
            guard (token.server == .phi || token.server == .phi2) && token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) else { return .just(nil) }
            return .just("WPHI")
        }
    }
}
