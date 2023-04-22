//
//  CoinGeckoCoinTickerNetworking.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2022.
//

import Foundation
import Combine
import SwiftyJSON
import AlphaWalletCore
import AlphaWalletLogger

public class FakeCoinTickerNetworking: CoinTickerNetworking {
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

public class CoinGeckoCoinTickerNetworking: CoinTickerNetworking {

    static var allHTTPHeaderFields: [String: String]? = [
        "Content-type": "application/json",
        "client": Bundle.main.bundleIdentifier ?? "",
        "client-build": Bundle.main.buildNumber ?? "",
    ]

    private let decoder = JSONDecoder()
    private let transporter: ApiTransporter
    private let analytics: AnalyticsLogger

    init(transporter: ApiTransporter, analytics: AnalyticsLogger) {
        self.transporter = transporter
        self.analytics = analytics
    }

    private func log(response: URLRequest.Response) {
        switch URLRequest.validate(statusCode: 200..<300, response: response.response) {
        case .failure:
            let error = try? decoder.decode(CoinGeckoErrorResponse.self, from: response.data)
            let message = error?.status.message ?? ""
            infoLog("[CoinGecko] request failure with status code: \(response.response.statusCode), message: \(message)")

            switch CoinGeckoApiError(statusCode: response.response.statusCode) {
            case .rateLimited:
                analytics.log(error: Analytics.WebApiErrors.coinGeckoRateLimited)
            case .internal:
                break
            }
        case .success:
            break
        }
    }

    public func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], PromiseError> {
        transporter
            .dataTaskPublisher(TokensThatHasPricesRequest())
            .handleEvents(receiveOutput: { self.log(response: $0) })
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
        return transporter
            .dataTaskPublisher(PriceHistoryOfTokenRequest(id: tickerId, currency: currency.code, days: period.rawValue))
            .handleEvents(receiveOutput: { self.log(response: $0) })
            .tryMap { try ChartHistory(json: try JSON(data: $0.data), currency: currency) }
            .mapError { PromiseError.some(error: $0) }
            .share()
            .eraseToAnyPublisher()
    }

    private func fetchPricesPage(for tickerIds: String, page: Int, currency: Currency) -> AnyPublisher<[CoinTicker], PromiseError> {
        return transporter
            .dataTaskPublisher(PricesOfTokensRequest(ids: tickerIds, currency: currency.code, page: page))
            .handleEvents(receiveOutput: { self.log(response: $0) })
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

    private struct CoinGeckoError: Decodable, Error {
        enum CodingKeys: String, CodingKey {
            case code = "error_code"
            case message = "error_message"
        }

        let code: Int
        let message: String
    }

    private enum CoinGeckoApiError: Error {
        case rateLimited
        case `internal`

        init(statusCode: Int) {
            switch statusCode {
            case 429:
                self = .rateLimited
            default:
                self = .internal
            }
        }
    }
}

extension CoinGeckoCoinTickerNetworking {
    struct TokensThatHasPricesRequest: URLRequestConvertible {
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.Coingecko.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v3/coins/list"
            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = CoinGeckoCoinTickerNetworking.allHTTPHeaderFields

            return try URLEncoding().encode(request, with: ["include_platform": "true"])
        }
    }

    struct PricesOfTokensRequest: URLRequestConvertible {
        let ids: String
        let currency: String
        let page: Int

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.Coingecko.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v3/coins/markets"

            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = CoinGeckoCoinTickerNetworking.allHTTPHeaderFields

            return try URLEncoding().encode(request, with: [
                "vs_currency": currency,
                "ids": ids,
                "price_change_percentage": "24h",
                "page": page,
                //Max according to https://www.coingecko.com/en/api
                "per_page": 250,
            ])
        }
    }

    struct PriceHistoryOfTokenRequest: URLRequestConvertible {
        let id: String
        let currency: String
        let days: Int

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.Coingecko.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v3/coins/\(id)/market_chart"

            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = CoinGeckoCoinTickerNetworking.allHTTPHeaderFields

            return try URLEncoding().encode(request, with: [
                "vs_currency": currency,
                "days": days
            ])
        }
    }
}
