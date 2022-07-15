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
        let persistentStorage: StorageType = InMemoryStorage()

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

extension CoinTicker {
    static func make(for token: TokenMappedToTicker) -> CoinTicker {
        let id = "tickerId-\(token.contractAddress)-\(token.server.chainID)"
        return .init(id: id, symbol: "", price_usd: 0.0, percent_change_24h: 0.0, market_cap: 0.0, market_cap_rank: 0.0, total_volume: 0.0, high_24h: 0.0, low_24h: 0.0, market_cap_change_24h: 0.0, market_cap_change_percentage_24h: 0.0, circulating_supply: 0.0, total_supply: 0.0, max_supply: 0.0, ath: 0.0, ath_change_percentage: 0.0)
    }

    func override(price_usd: Double) -> CoinTicker {
        return .init(id: id, symbol: symbol, price_usd: price_usd, percent_change_24h: percent_change_24h, market_cap: market_cap, market_cap_rank: market_cap_rank, total_volume: total_volume, high_24h: high_24h, low_24h: low_24h, market_cap_change_24h: market_cap_change_24h, market_cap_change_percentage_24h: market_cap_change_percentage_24h, circulating_supply: circulating_supply, total_supply: total_supply, max_supply: max_supply, ath: ath, ath_change_percentage: ath_change_percentage)
    }
}
