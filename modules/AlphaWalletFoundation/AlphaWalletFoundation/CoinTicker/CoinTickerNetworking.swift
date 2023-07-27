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
    func fetchSupportedTickerIds() async throws -> [TickerId]
    func fetchTickers(for tickerIds: [TickerIdString], currency: Currency) async throws -> [CoinTicker]
    func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: Currency) async throws -> ChartHistory
}
