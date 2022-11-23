//
//  CoinGeckoRequests.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 15.09.2022.
//

import Foundation

extension CoinGeckoNetworkProvider {
    private static var allHTTPHeaderFields: [String: String]? = [
        "Content-type": "application/json",
        "client": Bundle.main.bundleIdentifier ?? "",
        "client-build": Bundle.main.buildNumber ?? "",
    ]

    struct TokensThatHasPricesRequest: URLRequestConvertible {
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.Coingecko.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/v3/coins/list"
            var request = try URLRequest(url: components.asURL(), method: .get)
            request.allHTTPHeaderFields = CoinGeckoNetworkProvider.allHTTPHeaderFields

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
            request.allHTTPHeaderFields = CoinGeckoNetworkProvider.allHTTPHeaderFields

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
            request.allHTTPHeaderFields = CoinGeckoNetworkProvider.allHTTPHeaderFields

            return try URLEncoding().encode(request, with: [
                "vs_currency": currency,
                "days": days
            ])
        }
    }
}
