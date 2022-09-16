//
//  CoinTickerNetworkProviderType.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 16.09.2022.
//

import Foundation
import Combine

public enum CoinTickerNetworkProviderError: Error {
    case underlying(Error)
}

public protocol CoinTickerNetworkProviderType {
    func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], CoinTickerNetworkProviderError>
    func fetchTickers(for tickerIds: [TickerIdString], currency: String) -> AnyPublisher<[CoinTicker], CoinTickerNetworkProviderError>
    func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: String) -> AnyPublisher<ChartHistory, CoinTickerNetworkProviderError>
}
