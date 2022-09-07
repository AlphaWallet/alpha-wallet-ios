// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Moya

public enum AlphaWalletService {
    case tokensThatHasPrices
    case pricesOfTokens(ids: String, currency: String, page: Int)
    case getTransactions(server: RPCServer, address: AlphaWallet.Address, startBlock: Int, endBlock: Int, sortOrder: SortOrder)
    case oneInchTokens
    case honeySwapTokens
    case rampAssets
    case priceHistoryOfToken(id: String, currency: String, days: Int)

    public enum SortOrder: String {
        case asc
        case desc
    }
}

extension AlphaWalletService: TargetType {
    public var baseURL: URL {
        switch self {
        case .tokensThatHasPrices:
            return Constants.Coingecko.baseUrl
        case .pricesOfTokens:
            return Constants.Coingecko.baseUrl
        case .getTransactions(let server, _, _, _, _):
            if let url = server.transactionInfoEndpoints {
                return url
            } else {
                //HACK: we intentionally return an invalid, but non-nil URL because that's what the function needs to return. Keeps the code simple, yet still harmless
                return URL(string: "x")!
            }
        case .oneInchTokens:
            return Constants.OneInch.exchangeUrl
        case .honeySwapTokens:
            return Constants.HoneySwap.exchangeUrl
        case .rampAssets:
            return Constants.Ramp.exchangeUrl
        case .priceHistoryOfToken:
            return Constants.Coingecko.baseUrl
        }
    }

    public var path: String {
        switch self {
        case .getTransactions:
            return ""
        case .oneInchTokens:
            return "/v3.0/1/tokens"
        case .honeySwapTokens:
            return ""
        case .rampAssets:
            return "/api/host-api/assets"
        case .tokensThatHasPrices:
            return "/api/v3/coins/list"
        case .pricesOfTokens:
            return "/api/v3/coins/markets"
        case .priceHistoryOfToken(let id, _, _):
            return "/api/v3/coins/\(id)/market_chart"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .getTransactions: return .get
        case .pricesOfTokens: return .get
        case .oneInchTokens: return .get
        case .honeySwapTokens: return .get
        case .rampAssets: return .get
        case .tokensThatHasPrices: return .get
        case .priceHistoryOfToken: return .get
        }
    }

    public var task: Task {
        switch self {
        case .getTransactions(let server, let address, let startBlock, let endBlock, let sortOrder):
            var parameters: [String: Any] = [
                "module": "account",
                "action": "txlist",
                "address": address,
                "startblock": startBlock,
                "endblock": endBlock,
                "sort": sortOrder.rawValue,
            ]
            if let apiKey = server.etherscanApiKey {
                parameters["apikey"] = apiKey
            } else {
                //no-op
            }
            return .requestParameters(parameters: parameters, encoding: URLEncoding())
        case .pricesOfTokens(let ids, let currency, let page):
            return .requestParameters(parameters: [
                "vs_currency": currency,
                "ids": ids,
                "price_change_percentage": "24h",
                "page": page,
                //Max according to https://www.coingecko.com/en/api
                "per_page": 250,
            ], encoding: URLEncoding())
        case .oneInchTokens, .honeySwapTokens, .rampAssets:
            return .requestPlain
        case .tokensThatHasPrices:
            return .requestParameters(parameters: ["include_platform": "true"], encoding: URLEncoding())
        case .priceHistoryOfToken(_, let currency, let days):
            return .requestParameters(parameters: [
                "vs_currency": currency,
                "days": days
            ], encoding: URLEncoding())
        }
    }

    public var sampleData: Data {
        return Data()
    }

    public var headers: [String: String]? {
        switch self {
        case .getTransactions:
            return [
                "Content-type": "application/json",
                "client": Bundle.main.bundleIdentifier ?? "",
                "client-build": Bundle.main.buildNumber ?? "",
            ]
        case .priceHistoryOfToken, .tokensThatHasPrices, .pricesOfTokens:
            return [
                "Content-type": "application/json",
                "client": Bundle.main.bundleIdentifier ?? "",
                "client-build": Bundle.main.buildNumber ?? "",
            ]
        case .oneInchTokens, .honeySwapTokens, .rampAssets:
            return nil
        }
    }
}
