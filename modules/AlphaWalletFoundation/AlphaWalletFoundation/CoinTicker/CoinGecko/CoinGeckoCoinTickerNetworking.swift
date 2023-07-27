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
    public func fetchSupportedTickerIds() async throws -> [TickerId] {
        return []
    }

    public func fetchTickers(for tickerIds: [TickerIdString], currency: Currency) async throws -> [CoinTicker] {
        return []
    }

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: Currency) async throws -> ChartHistory {
        return ChartHistory.empty(currency: currency)
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

    public func fetchSupportedTickerIds() async throws -> [TickerId] {
        let response = try await transporter.dataTask(TokensThatHasPricesRequest())
        log(response: response)
        return try decoder.decode([TickerId].self, from: response.data)
    }

    public func fetchTickers(for tickerIds: [TickerIdString], currency: Currency) async throws -> [CoinTicker] {
        let ids = Set(tickerIds).joined(separator: ",")
        var page = 1
        var allResults: [CoinTicker] = .init()
        func fetchPageImpl() async throws -> [CoinTicker] {
            let results = try await fetchPricesPage(for: ids, page: page, currency: currency)
            if results.isEmpty {
                return allResults
            } else {
                allResults.append(contentsOf: results)
                page += 1
                return try await fetchPageImpl()
            }
        }
        return try await fetchPageImpl()
    }

    public func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: Currency) async throws -> ChartHistory {
        let response = try await transporter.dataTask(PriceHistoryOfTokenRequest(id: tickerId, currency: currency.code, days: period.rawValue))
        log(response: response)
        return try ChartHistory(json: try JSON(data: response.data), currency: currency)
    }

    private func fetchPricesPage(for tickerIds: String, page: Int, currency: Currency) async throws -> [CoinTicker] {
        let response = try await transporter.dataTask(PricesOfTokensRequest(ids: tickerIds, currency: currency.code, page: page))
        log(response: response)
        do {
            let coinTickers = try decoder.decode([CoinTicker].self, from: response.data)
            //NOTE: we re not able to set currency in init method, using `override(currency: )` instead
            return coinTickers.map { $0.override(currency: currency) }
        } catch {
            if let response = try? decoder.decode(CoinGeckoErrorResponse.self, from: response.data) {
                throw response.status
            } else {
                throw error
            }
        }
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
