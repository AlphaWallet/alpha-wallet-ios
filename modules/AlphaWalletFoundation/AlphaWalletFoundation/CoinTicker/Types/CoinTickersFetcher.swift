// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import Combine

public protocol CoinTickersFetcher {
    func fetchTickers(for tokens: [TokenMappedToTicker], force: Bool, currency: Currency) async
    func resolveTickerIds(for tokens: [TokenMappedToTicker]) async
    func fetchChartHistories(for token: TokenMappedToTicker, force: Bool, periods: [ChartHistoryPeriod], currency: Currency) async -> [ChartHistoryPeriod: ChartHistory]
    func cancel() async
}
