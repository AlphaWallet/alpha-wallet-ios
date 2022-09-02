//
//  CovalentNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Alamofire
import SwiftyJSON 
import Combine
import APIKit
import AlphaWalletCore

public extension Covalent {
    public enum CovalentError: Error {
        case jsonDecodeFailure
        case requestFailure(PromiseError)
        case sessionError(SessionTaskError)
    }

    public final class NetworkProvider {
        private let key = Constants.Credentials.covalentApiKey

        func transactions(walletAddress: AlphaWallet.Address, server: RPCServer, page: Int? = nil, pageSize: Int = 5, blockSignedAtAsc: Bool = false) -> AnyPublisher<TransactionsResponse, CovalentError> {
            return Alamofire
                .request(ApiUrlProvider.transactions(walletAddress: walletAddress, server: server, page: page, pageSize: pageSize, apiKey: key, blockSignedAtAsc: blockSignedAtAsc))
                .validate()
                .responseJSONPublisher(options: [])
                .tryMap { response -> TransactionsResponse in
                    guard let rawJson = response.json as? [String: Any] else { throw CovalentError.jsonDecodeFailure }
                    return try TransactionsResponse(json: JSON(rawJson))
                }
                .mapError { return CovalentError.requestFailure(.some(error: $0)) }
                .eraseToAnyPublisher()
        }

        func balances(walletAddress: AlphaWallet.Address, server: RPCServer, quoteCurrency: String, nft: Bool, noNftFetch: Bool) -> AnyPublisher<BalancesResponse, CovalentError> {
            return Alamofire
                .request(ApiUrlProvider.balances(walletAddress: walletAddress, server: server, quoteCurrency: quoteCurrency, nft: nft, noNftFetch: noNftFetch, apiKey: key))
                .validate()
                .responseJSONPublisher(options: [])
                .tryMap { response -> BalancesResponse in
                    guard let rawJson = response.json as? [String: Any] else { throw CovalentError.jsonDecodeFailure }
                    return try BalancesResponse(json: JSON(rawJson))
                }
                .mapError { return CovalentError.requestFailure(.some(error: $0)) }
                .eraseToAnyPublisher()
        }
    }
}
