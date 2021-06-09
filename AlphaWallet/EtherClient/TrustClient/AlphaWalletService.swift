// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Moya

enum AlphaWalletService {
    case tokensThatHasPrices(config: Config)
    case pricesOfTokens(config: Config, ids: String, currency: String, page: Int)
    case getTransactions(config: Config, server: RPCServer, address: AlphaWallet.Address, startBlock: Int, endBlock: Int, sortOrder: SortOrder)
    case register(config: Config, device: PushDevice)
    case unregister(config: Config, device: PushDevice)
    case marketplace(config: Config, server: RPCServer)
    case gasPriceEstimate
    case oneInchTokens(config: Config)
    case honeySwapTokens(config: Config)
    case rampAssets(config: Config)
    case priceHistoryOfToken(config: Config, id: String, currency: String, days: Int)

    enum SortOrder: String {
        case asc
        case desc
    }
}

extension AlphaWalletService: TargetType {
    var baseURL: URL {
        switch self {
        case .tokensThatHasPrices(let config):
            return config.priceInfoEndpoints
        case .pricesOfTokens(let config, _, _, _):
            return config.priceInfoEndpoints
        case .getTransactions(_, let server, _, _, _, _):
            if let url = server.transactionInfoEndpoints {
                return url
            } else {
                //HACK: we intentionally return an invalid, but non-nil URL because that's what the function needs to return. Keeps the code simple, yet still harmless
                return URL(string: "x")!
            }
        case .register(let config, _), .unregister(let config, _):
            return config.priceInfoEndpoints
        case .marketplace(let config, _):
            return config.priceInfoEndpoints
        case .gasPriceEstimate:
            return URL(string: Constants.gasNowEndpointBaseUrl)!
        case .oneInchTokens(let config):
            return config.oneInch
        case .honeySwapTokens(let config):
            return config.honeySwapTokens
        case .rampAssets(let config):
            return config.rampAssets
        case .priceHistoryOfToken(let config, _, _, _):
            return config.priceInfoEndpoints
        }
    }

    var path: String {
        switch self {
        case .getTransactions(_, let server, _, _, _, _):
            switch server {
            case .main, .classic, .callisto, .kovan, .ropsten, .custom, .rinkeby, .poa, .sokol, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan:
                return ""
            }
        case .register:
            return "/push/register"
        case .unregister:
            return "/push/unregister"
        case .marketplace:
            return "/marketplace"
        case .gasPriceEstimate:
            return "/api/v3/gas/price"
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
        case .priceHistoryOfToken(_, let id, _, _):
            return "/api/v3/coins/\(id)/market_chart"
        }
    }

    var method: Moya.Method {
        switch self {
        case .getTransactions: return .get
        case .register: return .post
        case .unregister: return .delete
        case .pricesOfTokens: return .get
        case .marketplace: return .get
        case .gasPriceEstimate: return .get
        case .oneInchTokens: return .get
        case .honeySwapTokens: return .get
        case .rampAssets: return .get
        case .tokensThatHasPrices: return .get
        case .priceHistoryOfToken: return .get
        }
    }

    var task: Task {
        switch self {
        case .getTransactions(_, let server, let address, let startBlock, let endBlock, let sortOrder):
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
        case .register(_, let device):
            return .requestJSONEncodable(device)
        case .unregister(_, let device):
            return .requestJSONEncodable(device)
        case .pricesOfTokens(_, let ids, let currency, let page):
            return .requestParameters(parameters: [
                "vs_currency": currency,
                "ids": ids,
                "price_change_percentage": "24h",
                "page": page,
                //Max according to https://www.coingecko.com/en/api
                "per_page": 250,
            ], encoding: URLEncoding())
        case .marketplace(_, let server):
            return .requestParameters(parameters: ["chainID": server.chainID], encoding: URLEncoding())
        case .gasPriceEstimate:
            return .requestPlain
        case .oneInchTokens, .honeySwapTokens, .rampAssets:
            return .requestPlain
        case .tokensThatHasPrices:
            return .requestParameters(parameters: ["include_platform": "true"], encoding: URLEncoding())
        case .priceHistoryOfToken(_, _, let currency, let days):
            return .requestParameters(parameters: [
                "vs_currency": currency,
                "days": days
            ], encoding: URLEncoding())
        }
    }

    var sampleData: Data {
        return Data()
    }

    var headers: [String: String]? {
        switch self {
        case .getTransactions(_, let server, _, _, _, _):
            switch server {
            case .main, .classic, .callisto, .kovan, .ropsten, .custom, .rinkeby, .poa, .sokol, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan:
                return [
                    "Content-type": "application/json",
                    "client": Bundle.main.bundleIdentifier ?? "",
                    "client-build": Bundle.main.buildNumber ?? "",
                ]
            }
        case .priceHistoryOfToken, .tokensThatHasPrices, .pricesOfTokens, .register, .unregister, .marketplace, .gasPriceEstimate:
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
