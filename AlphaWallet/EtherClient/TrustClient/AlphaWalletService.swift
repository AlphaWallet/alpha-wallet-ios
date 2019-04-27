// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Moya

enum AlphaWalletService {
    case priceOfEth(config: Config)
    case priceOfDai(config: Config)
    case getTransactions(config: Config, server: RPCServer, address: String, startBlock: Int, endBlock: Int, sortOrder: SortOrder)
    case getTransaction(config: Config, ID: String)
    case register(config: Config, device: PushDevice)
    case unregister(config: Config, device: PushDevice)
    case marketplace(config: Config, server: RPCServer)

    enum SortOrder: String {
        case asc
        case desc
    }
}

extension AlphaWalletService: TargetType {
    var baseURL: URL {
        switch self {
        case .getTransactions(_, let server, _, _, _, _):
            return server.transactionInfoEndpoints
        case .priceOfEth(let config), .priceOfDai(let config):
            return config.priceInfoEndpoints
        case .getTransaction(let config, _), .register(let config, _), .unregister(let config, _):
            return config.priceInfoEndpoints
        case .marketplace(let config, _):
            return config.priceInfoEndpoints
        }
    }

    var path: String {
        switch self {
        case .getTransactions:
            return "/api"
        case .getTransaction(let txId):
            return "/api?module=transaction&action=gettxreceiptstatus&txhash=/\(txId)"
        case .register:
            return "/push/register"
        case .unregister:
            return "/push/unregister"
        case .priceOfEth:
            return "/v1/ticker/ethereum/"
        case .priceOfDai:
            return "/v1/ticker/dai/"
        case .marketplace:
            return "/marketplace"
        }
    }

    var method: Moya.Method {
        switch self {
        case .getTransactions: return .get
        case .getTransaction: return .get
        case .register: return .post
        case .unregister: return .delete
        case .priceOfEth: return .get
        case .priceOfDai: return .get
        case .marketplace: return .get
        }
    }

    var task: Task {
        switch self {
        case .getTransactions(_, _, let address, let startBlock, let endBlock, let sortOrder):
            return .requestParameters(parameters: [
                "module": "account",
                "action": "txlist",
                "address": address,
                "startblock": startBlock,
                "endblock": endBlock,
                "sort": sortOrder.rawValue,
            ], encoding: URLEncoding())
        case .getTransaction:
            return .requestPlain
        case .register(_, let device):
            return .requestJSONEncodable(device)
        case .unregister(_, let device):
            return .requestJSONEncodable(device)
        case .priceOfEth, .priceOfDai:
            return .requestPlain
        case .marketplace(_, let server):
            return .requestParameters(parameters: ["chainID": server.chainID], encoding: URLEncoding())
        }
    }

    var sampleData: Data {
        return Data()
    }

    var headers: [String: String]? {
        return [
            "Content-type": "application/json",
            "client": Bundle.main.bundleIdentifier ?? "",
            "client-build": Bundle.main.buildNumber ?? "",
        ]
    }
}
