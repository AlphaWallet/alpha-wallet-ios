//
//  CovalentUrlProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Foundation

extension Covalent {
    struct TransactionsRequest: URLRequestConvertible {
        let walletAddress: AlphaWallet.Address
        let server: RPCServer
        let page: Int?
        let pageSize: Int
        let apiKey: String
        let blockSignedAtAsc: Bool

        func asURLRequest() throws -> URLRequest {
            guard var components: URLComponents = .init(url: Constants.Covalent.apiBaseUrl, resolvingAgainstBaseURL: false) else {
                throw URLError(.badURL)
            }

            components.path = "/v1/\(server.chainID)/address/\(walletAddress)/transactions_v2/"

            let url = try components.asURL()
            let request = try URLRequest(url: url, method: .get)

            return try URLEncoding().encode(request, with: [
                "key": apiKey,
                "block-signed-at-asc": "\(blockSignedAtAsc)",
                "page-number": "\(page ?? 0)",
                "page-size": "\(pageSize)"
            ])
        }
    }

}
