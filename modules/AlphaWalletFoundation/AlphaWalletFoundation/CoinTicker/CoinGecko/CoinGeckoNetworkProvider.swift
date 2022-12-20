//
//  CoinGeckoNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2022.
//

import Foundation
import Combine
import SwiftyJSON
import AlphaWalletCore

public class FakeCoinGeckoNetworkProvider: CoinTickerNetworkProviderType {
    public init() {}
    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], PromiseError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: [String], currency: Currency) -> AnyPublisher<[CoinTicker], PromiseError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: Currency) -> AnyPublisher<ChartHistory, PromiseError> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}

public class CoinGeckoNetworkProvider: CoinTickerNetworkProviderType {
    private let decoder = JSONDecoder()
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], PromiseError> {
        networkService
            .dataTaskPublisher(TokensThatHasPricesRequest())
            .retry(times: 3)
            .tryMap { [decoder] in try decoder.decode([TickerId].self, from: $0.data) }
            .mapError { PromiseError.some(error: $0) }
            .share()
            .eraseToAnyPublisher()
    }

    public func fetchTickers(for tickerIds: [TickerIdString], currency: Currency) -> AnyPublisher<[CoinTicker], PromiseError> {
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

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: Currency) -> AnyPublisher<ChartHistory, PromiseError> {
        return networkService
            .dataTaskPublisher(PriceHistoryOfTokenRequest(id: tickerId, currency: currency.code, days: period.rawValue))
            .retry(times: 3)
            .tryMap { try ChartHistory(json: try JSON(data: $0.data), currency: currency) }
            .mapError { PromiseError.some(error: $0) }
            .share()
            .eraseToAnyPublisher()
    }

    private func fetchPricesPage(for tickerIds: String, page: Int, currency: Currency) -> AnyPublisher<[CoinTicker], PromiseError> {
        return networkService
            .dataTaskPublisher(PricesOfTokensRequest(ids: tickerIds, currency: currency.code, page: page))
            .retry(times: 3)
            .tryMap { [decoder] in
                do {
                    return try decoder.decode([CoinTicker].self, from: $0.data)
                } catch {
                    if let response = try? decoder.decode(CoinGeckoErrorResponse.self, from: $0.data) {
                        throw PromiseError.some(error: response.status)
                    } else {
                        throw error
                    }
                }
            }
            .map { $0.map { $0.override(currency: currency) } }//NOTE: we re not able to set currency in init method, using `override(currency: )` instead
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private struct CoinGeckoErrorResponse: Decodable {
        let status: CoinGeckoError
    }

    struct CoinGeckoError: Decodable, Error {
        enum CodingKeys: String, CodingKey {
            case code = "error_code"
            case message = "error_message"
        }

        let code: Int
        let message: String
    }
}
