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

extension CoinGeckoTickersFetcher {
    static func make(config: Config = .make()) -> CoinTickersFetcher {
        let networkProvider: CoinGeckoNetworkProviderType = FakeCoinGeckoNetworkProvider()
        let persistentStorage: StorageType = try! FileStorage.forTestSuite(folder: "testSuiteForTickersStorage", fileExtension: "json")

        let storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage = CoinTickersFileStorage(config: config, storage: persistentStorage)
        let coinGeckoTickerIdsFetcher = CoinGeckoTickerIdsFetcher(networkProvider: networkProvider, storage: storage, config: config)
        let fileTokenEntriesProvider = FileTokenEntriesProvider(fileName: "tokens_2")

        let tickerIdsFetcher: TickerIdsFetcher = TickerIdsFetcherImpl(providers: [
            InMemoryTickerIdsFetcher(storage: storage),
            coinGeckoTickerIdsFetcher,
            AlphaWalletRemoteTickerIdsFetcher(provider: fileTokenEntriesProvider, tickerIdsFetcher: coinGeckoTickerIdsFetcher)
        ])

        return CoinGeckoTickersFetcher(networkProvider: networkProvider, storage: storage, tickerIdsFetcher: tickerIdsFetcher)
    }
}
