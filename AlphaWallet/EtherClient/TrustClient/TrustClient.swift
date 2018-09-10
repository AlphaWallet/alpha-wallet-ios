// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Moya

enum TrustService {
    case prices
    case getTransactions(address: String, startBlock: Int, endBlock: Int)
    case getTransaction(ID: String)
    case register(device: PushDevice)
    case unregister(device: PushDevice)
    case marketplace(chainID: Int)
}

extension TrustService: TargetType {
    var baseURL: URL {
        switch self {
        case .getTransactions:
            return Config().transactionInfoEndpoints
        case .prices:
            return Config().priceInfoEndpoints
        case .getTransaction, .register, .unregister, .marketplace:
            //TODO this wouldn't be needed after we remove these unused cases
            return Config().priceInfoEndpoints
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
        case .prices:
            return "/v1/ticker/ethereum/"
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
        case .prices: return .get
        case .marketplace: return .get
        }
    }

    var task: Task {
        switch self {
        case .getTransactions(let address, let startBlock, let endBlock):
            return .requestParameters(parameters: [
                "module": "account",
                "action": "txlist",
                "address": address,
                "startblock": startBlock,
                "endblock": endBlock,
            ], encoding: URLEncoding())
        case .getTransaction:
            return .requestPlain
        case .register(let device):
            return .requestJSONEncodable(device)
        case .unregister(let device):
            return .requestJSONEncodable(device)
        case .prices:
            return .requestPlain
        case .marketplace(let chainID):
            return .requestParameters(parameters: ["chainID": chainID], encoding: URLEncoding())
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
