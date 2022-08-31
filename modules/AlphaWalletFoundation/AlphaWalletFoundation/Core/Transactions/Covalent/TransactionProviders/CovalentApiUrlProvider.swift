//
//  CovalentUrlProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Foundation
import Alamofire

extension Covalent {
    enum ApiUrlProvider: URLConvertible {
        case transactions(walletAddress: AlphaWallet.Address, server: RPCServer, page: Int?, pageSize: Int, apiKey: String, blockSignedAtAsc: Bool)
        case balances(walletAddress: AlphaWallet.Address, server: RPCServer, quoteCurrency: String, nft: Bool, noNftFetch: Bool, apiKey: String)

        func asURL() throws -> URL {
            guard var components: URLComponents = .init(url: Constants.Covalent.apiBaseUrl, resolvingAgainstBaseURL: false) else {
                throw AFError.invalidURL(url: self)
            }

            switch self {
            case .transactions(let walletAddress, let server, let page, let pageSize, let apiKey, let blockSignedAtAsc):
                components.path = "/v1/\(server.chainID)/address/\(walletAddress)/transactions_v2/"
                components.queryItems = [
                    URLQueryItem(name: "key", value: apiKey),
                    URLQueryItem(name: "block-signed-at-asc", value: "\(blockSignedAtAsc)"),
                    URLQueryItem(name: "page-number", value: "\(page ?? 0)"),
                    URLQueryItem(name: "page-size", value: "\(pageSize)"),
                ]

            case .balances(let walletAddress, let server, let quoteCurrency, let nft, let noNftFetch, let apiKey):
                components.path = "/v1/\(server.chainID)/address/\(walletAddress)/balances_v2/"
                components.queryItems = [
                    URLQueryItem(name: "key", value: apiKey),
                    URLQueryItem(name: "quote-currency", value: quoteCurrency),
                    URLQueryItem(name: "format", value: "JSON"),
                    URLQueryItem(name: "nft", value: "\(nft)"),
                    URLQueryItem(name: "no-nft-fetch", value: "\(noNftFetch)")
                ]
            }

            guard let url = components.url else { throw AFError.invalidURL(url: self) }
            
            return url
        }
    }
}
