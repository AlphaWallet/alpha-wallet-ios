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
import AlphaWalletCore

public class FakeCoinGeckoNetworkProvider: CoinTickerNetworkProviderType {
    public init() {}
    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], PromiseError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: [String], currency: String) -> AnyPublisher<[CoinTicker], PromiseError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: String) -> AnyPublisher<ChartHistory, PromiseError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}

public class CoinGeckoNetworkProvider: CoinTickerNetworkProviderType {
    private let decoder = JSONDecoder()

    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], PromiseError> {
        Alamofire.request(TokensThatHasPricesRequest())
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { [decoder] in try decoder.decode([TickerId].self, from: $0.data) }
            .mapError { PromiseError.some(error: $0) }
            .share()
            .eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: [TickerIdString], currency: String) -> AnyPublisher<[CoinTicker], PromiseError> {
        let ids = Set(tickerIds).joined(separator: ",")
        var page = 1
        var allResults: [CoinTicker] = .init()
        func fetchPageImpl() -> AnyPublisher<[CoinTicker], PromiseError> {
            fetchPricesPage(for: ids, page: page, currency: currency)
                .flatMap { results -> AnyPublisher<[CoinTicker], PromiseError> in
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

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: String) -> AnyPublisher<ChartHistory, PromiseError> {
        return Alamofire.request(PriceHistoryOfTokenRequest(id: tickerId, currency: currency, days: period.rawValue))
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { try ChartHistory(json: try JSON(data: $0.data)) }
            .mapError { PromiseError.some(error: $0) }
            .share()
            .eraseToAnyPublisher()
    }

    private func fetchPricesPage(for tickerIds: String, page: Int, currency: String) -> AnyPublisher<[CoinTicker], PromiseError> {
        return Alamofire.request(PricesOfTokensRequest(ids: tickerIds, currency: currency, page: page))
            .responseDataPublisher()
            .retry(times: 3)
            .tryMap { [decoder] in try decoder.decode([CoinTicker].self, from: $0.data) }
            .map { $0.map { $0.override(currency: currency) } }//NOTE: we re not able to set currency in init method, using `override(currency: )` instead
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }
}
