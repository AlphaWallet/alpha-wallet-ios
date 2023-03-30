//
//  CoinTickerNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 16.09.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public protocol CoinTickerNetworking {
    func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], PromiseError>
    func fetchTickers(for tickerIds: [TickerIdString], currency: Currency) -> AnyPublisher<[CoinTicker], PromiseError>
    func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: Currency) -> AnyPublisher<ChartHistory, PromiseError>
}
