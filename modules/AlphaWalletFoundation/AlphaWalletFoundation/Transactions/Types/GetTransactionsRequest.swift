//
//  GetTransactionsRequest.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 15.09.2022.
//

import Foundation
import Alamofire

struct GetTransactions: URLRequestConvertible {
    let server: RPCServer
    let address: AlphaWallet.Address
    let startBlock: Int
    let endBlock: Int
    let sortOrder: SortOrder

    public enum SortOrder: String {
        case asc
        case desc
    }

    func asURLRequest() throws -> URLRequest {
        guard let url = server.transactionInfoEndpoints else { throw URLError(.badURL) }

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

        var request = try URLRequest(url: url, method: .get)
        request.allHTTPHeaderFields = [
            "Content-type": "application/json",
            "client": Bundle.main.bundleIdentifier ?? "",
            "client-build": Bundle.main.buildNumber ?? "",
        ]

        return try URLEncoding().encode(URLRequest(url: url, method: .get), with: parameters)
    }
}
