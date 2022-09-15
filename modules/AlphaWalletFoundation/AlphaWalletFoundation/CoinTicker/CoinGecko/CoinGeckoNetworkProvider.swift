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

public enum CoinGeckoNetworkProviderError: Error {
    case underlying(Error)
}

public protocol CoinGeckoNetworkProviderType {
    func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], CoinGeckoNetworkProviderError>
    func fetchTickers(for tickerIds: String) -> AnyPublisher<[CoinTicker], CoinGeckoNetworkProviderError>
    func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String) -> AnyPublisher<ChartHistory, CoinGeckoNetworkProviderError>
}

public class FakeCoinGeckoNetworkProvider: CoinGeckoNetworkProviderType {
    public init() {}
    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], CoinGeckoNetworkProviderError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: String) -> AnyPublisher<[CoinTicker], CoinGeckoNetworkProviderError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String) -> AnyPublisher<ChartHistory, CoinGeckoNetworkProviderError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}

public class CoinGeckoNetworkProvider: CoinGeckoNetworkProviderType {
    private let decoder = JSONDecoder()

    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], CoinGeckoNetworkProviderError> {
        Alamofire.request(TokensThatHasPricesRequest())
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { [decoder] in try decoder.decode([TickerId].self, from: $0.data) }
            .mapError { CoinGeckoNetworkProviderError.underlying($0) }
            .share()
            .eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: String) -> AnyPublisher<[CoinTicker], CoinGeckoNetworkProviderError> {
        var page = 1
        var allResults: [CoinTicker] = .init()
        func fetchPageImpl() -> AnyPublisher<[CoinTicker], CoinGeckoNetworkProviderError> {
            fetchPricesPage(for: tickerIds, page: page, shouldRetry: true)
                .flatMap { results -> AnyPublisher<[CoinTicker], CoinGeckoNetworkProviderError> in
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

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String) -> AnyPublisher<ChartHistory, CoinGeckoNetworkProviderError> {
        return Alamofire.request(PriceHistoryOfTokenRequest.init(id: tickerId, currency: Currency.USD.rawValue, days: period.rawValue))
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { try ChartHistory(json: try JSON(data: $0.data)) }
            .mapError { CoinGeckoNetworkProviderError.underlying($0) }
            .share()
            .eraseToAnyPublisher()
    }

    private func fetchPricesPage(for tickerIds: String, page: Int, shouldRetry: Bool) -> AnyPublisher<[CoinTicker], CoinGeckoNetworkProviderError> {
        return Alamofire.request(PricesOfTokensRequest(ids: tickerIds, currency: Currency.USD.rawValue, page: page))
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { [decoder] in try decoder.decode([CoinTicker].self, from: $0.data) }
            .mapError { CoinGeckoNetworkProviderError.underlying($0) }
            .eraseToAnyPublisher()
    }
}
