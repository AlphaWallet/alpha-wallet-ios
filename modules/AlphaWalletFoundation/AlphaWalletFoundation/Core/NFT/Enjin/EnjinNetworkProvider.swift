//
//  EnjinNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.04.2022.
//

import Foundation
import AlphaWalletCore
import AlphaWalletOpenSea
import Apollo
import PromiseKit

final class EnjinNetworkProvider {
    static let client = URLSessionClient()
    static let cache = InMemoryNormalizedCache()
    static var store = ApolloStore(cache: cache)
    private let queue: DispatchQueue

    private lazy var graphqlClient: ApolloClient = {
        let provider = NetworkInterceptorProvider(store: EnjinNetworkProvider.store, client: EnjinNetworkProvider.client)
        let transport = RequestChainNetworkTransport(interceptorProvider: provider, endpointURL: Constants.Enjin.apiUrl)

        return ApolloClient(networkTransport: transport, store: EnjinNetworkProvider.store)
    }()

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    typealias GetEnjinBalancesResponse = (balances: Enjin.MappedEnjinBalances, owner: AlphaWallet.Address)

    func getEnjinBalances(forOwner owner: AlphaWallet.Address, offset: Int, sum: Enjin.MappedEnjinBalances = [:], limit: Int = 50, completion: @escaping (Swift.Result<GetEnjinBalancesResponse, EnjinError>) -> Void) {

        graphqlClient.fetch(query: GetEnjinBalancesQuery(ethAddress: owner.eip55String, page: offset, limit: limit), queue: queue) { response in
            switch response {
            case .failure(let error):
                completion(.failure(EnjinError(localizedDescription: "Error calling Engin API: \(String(describing: error))")))
            case .success(let graphQLResult):
                var results = sum
                let balances: [GetEnjinBalancesQuery.Data.EnjinBalance]
                if let data = graphQLResult.data {
                    balances = (data.enjinBalances ?? []).compactMap { $0 }
                } else {
                    balances = []
                }

                if let values = results[owner] {
                    results[owner] = values + balances
                } else {
                    results[owner] = balances
                }

                if !balances.isEmpty {
                    self.getEnjinBalances(forOwner: owner, offset: offset + 1, sum: results) { results in
                        completion(results)
                    }
                } else {
                    completion(.success((sum, owner)))
                }
            }
        }
    }

    func getEnjinTokens(ids: [String], owner: AlphaWallet.Address) -> Promise<[AlphaWallet.Address: [GetEnjinTokenQuery.Data.EnjinToken]]> {
        if ids.isEmpty {
            return .value([owner: []])
        }

        let promises = ids.map { tokenId in
            return Promise<GetEnjinTokenQuery.Data.EnjinToken> { seal in
                graphqlClient.fetch(query: GetEnjinTokenQuery(id: tokenId), queue: queue) { response in
                    switch response {
                    case .failure(let error):
                        seal.reject(error)
                    case .success(let graphQLResult):
                        guard let token = graphQLResult.data?.enjinToken else {
                            let error = EnjinError(localizedDescription: "Enjin token \(tokenId) not found")
                            return seal.reject(error)
                        }

                        seal.fulfill(token)
                    }
                }
            }
        }

        return when(resolved: promises).map { results in
            let tokens = results.compactMap { $0.optionalValue }
            return [owner: tokens]
        }
    }

}

extension Enjin {
    enum functional { }
}

extension Enjin.functional {

    private struct EnjinOauthFallbackDecoder {
        func decode(from body: JSONObject) -> EnjinOauthQuery.Data.EnjinOauth? {
            guard let data = body["data"] as? [String: Any], let authData = data["EnjinOauth"] as? [String: Any] else { return nil }
            guard let name = authData["name"] as? String else { return nil }
            guard let tokensJsons = authData["accessTokens"] as? [[String: Any]] else { return nil }

            let tokens = tokensJsons.compactMap { json in
                return json["accessToken"] as? String
            }
            guard !tokens.isEmpty else { return nil }
            return EnjinOauthQuery.Data.EnjinOauth.init(name: name, accessTokens: tokens)
        }
    }

    static func authorize(graphqlClient: ApolloClient, email: String, password: String) -> Promise<EnjinOauthQuery.Data.EnjinOauth> {
        return Promise<EnjinOauthQuery.Data.EnjinOauth> { seal in
            graphqlClient.fetch(query: EnjinOauthQuery(email: email, password: password)) { response in
                switch response {
                case .failure(let error):
                    switch error as? FallbackJSONResponseParsingInterceptor.JSONResponseParsingError {
                    case .caseToAvoidAuthDecodingError(let body):
                        guard let data = EnjinOauthFallbackDecoder().decode(from: body) else {
                            return seal.reject(error)
                        }
                        seal.fulfill(data)
                    case .couldNotParseToJSON, .noResponseToParse, .none:
                        seal.reject(error)
                    }
                case .success(let graphQLResult):
                    guard let data = graphQLResult.data?.enjinOauth else {
                        let error = OpenSeaError(localizedDescription: "Enjin authorization failure")
                        return seal.reject(error)
                    }

                    seal.fulfill(data)
                }
            }
        }
    }
}

final private class NetworkInterceptorProvider: InterceptorProvider {
    // These properties will remain the same throughout the life of the `InterceptorProvider`, even though they
    // will be handed to different interceptors.
    private let store: ApolloStore
    private let client: URLSessionClient
    private let enjinUserManagementInterceptor = EnjinUserManagementInterceptor()

    init(store: ApolloStore, client: URLSessionClient) {
        self.store = store
        self.client = client
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        return [
            MaxRetryInterceptor(),
            CacheReadInterceptor(store: self.store),
            enjinUserManagementInterceptor,
            NetworkFetchInterceptor(client: self.client),
            ResponseCodeInterceptor(),
            JSONResponseParsingInterceptor(cacheKeyForObject: self.store.cacheKeyForObject),
            AutomaticPersistedQueryInterceptor(),
            CacheWriteInterceptor(store: self.store)
        ]
    }
}

