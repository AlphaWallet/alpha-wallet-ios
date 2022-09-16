//
//  CoinGeckoNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2022.
//

import Foundation
import Combine
import SwiftyJSON
import Alamofire

public class FakeCoinGeckoNetworkProvider: CoinTickerNetworkProviderType {
    public init() {}
    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], CoinTickerNetworkProviderError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: [String], currency: String) -> AnyPublisher<[CoinTicker], CoinTickerNetworkProviderError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: String) -> AnyPublisher<ChartHistory, CoinTickerNetworkProviderError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}

public class CoinGeckoNetworkProvider: CoinTickerNetworkProviderType {
    private let decoder = JSONDecoder()

    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], CoinTickerNetworkProviderError> {
        Alamofire.request(TokensThatHasPricesRequest())
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { [decoder] in try decoder.decode([TickerId].self, from: $0.data) }
            .mapError { CoinTickerNetworkProviderError.underlying($0) }
            .share()
            .eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: [TickerIdString], currency: String) -> AnyPublisher<[CoinTicker], CoinTickerNetworkProviderError> {
        let ids = Set(tickerIds).joined(separator: ",")
        var page = 1
        var allResults: [CoinTicker] = .init()
        func fetchPageImpl() -> AnyPublisher<[CoinTicker], CoinTickerNetworkProviderError> {
            fetchPricesPage(for: ids, page: page, shouldRetry: true, currency: currency)
                .flatMap { results -> AnyPublisher<[CoinTicker], CoinTickerNetworkProviderError> in
                    if results.isEmpty {
                        return .just(allResults)
                    } else {
                        allResults.append(contentsOf: results)
                        page += 1
                        return fetchPageImpl()
                    }
                }.eraseToAnyPublisher()
        }

        return fetchPageImpl()
            .share()
            .eraseToAnyPublisher()
    }

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: String) -> AnyPublisher<ChartHistory, CoinTickerNetworkProviderError> {
        return Alamofire.request(PriceHistoryOfTokenRequest.init(id: tickerId, currency: currency, days: period.rawValue))
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { try ChartHistory(json: try JSON(data: $0.data)) }
            .mapError { CoinTickerNetworkProviderError.underlying($0) }
            .share()
            .eraseToAnyPublisher()
    }

    private func fetchPricesPage(for tickerIds: String, page: Int, shouldRetry: Bool, currency: String) -> AnyPublisher<[CoinTicker], CoinTickerNetworkProviderError> {
        return Alamofire.request(PricesOfTokensRequest(ids: tickerIds, currency: currency, page: page))
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { [decoder] in try decoder.decode([CoinTicker].self, from: $0.data) }
            .mapError { CoinTickerNetworkProviderError.underlying($0) }
            .eraseToAnyPublisher()
    }
}
