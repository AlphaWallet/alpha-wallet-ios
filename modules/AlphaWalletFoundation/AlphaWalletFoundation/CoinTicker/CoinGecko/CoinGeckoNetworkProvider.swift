//
//  CoinGeckoNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2022.
//

import Foundation
import Moya
import Combine
import SwiftyJSON

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
    private let provider: MoyaProvider<AlphaWalletService>
    private let decoder = JSONDecoder()

    public init(provider: MoyaProvider<AlphaWalletService>) {
        self.provider = provider
    }

    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], CoinGeckoNetworkProviderError> {
        provider.publisher(.tokensThatHasPrices, callbackQueue: .global())
            .retry(times: 3)
            .tryMap { [decoder] in try $0.map([TickerId].self, using: decoder) }
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
        provider.publisher(.priceHistoryOfToken(id: tickerId, currency: Constants.Currency.usd, days: period.rawValue), callbackQueue: .global())
            .retry(times: 3)
            .tryMap { try ChartHistory(json: try JSON(data: $0.data)) }
            .mapError { CoinGeckoNetworkProviderError.underlying($0) }
            .share()
            .eraseToAnyPublisher()
    }

    private func fetchPricesPage(for tickerIds: String, page: Int, shouldRetry: Bool) -> AnyPublisher<[CoinTicker], CoinGeckoNetworkProviderError> {
        return provider.publisher(.pricesOfTokens(ids: tickerIds, currency: Constants.Currency.usd, page: page), callbackQueue: .global())
            .retry(times: 3)
            .tryMap { [decoder] in try $0.map([CoinTicker].self, using: decoder) }
            .mapError { CoinGeckoNetworkProviderError.underlying($0) }
            .eraseToAnyPublisher()
    }
}
