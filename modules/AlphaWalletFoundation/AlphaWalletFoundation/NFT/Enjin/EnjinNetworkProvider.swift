//
//  EnjinNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.04.2022.
//

import Foundation
import AlphaWalletCore
import Apollo
import PromiseKit

final class EnjinNetworkProvider {
    private let queue: DispatchQueue

    private lazy var graphqlClient: ApolloClient = {
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)
        let provider = NetworkInterceptorProvider(store: store, client: URLSessionClient())
        let transport = RequestChainNetworkTransport(interceptorProvider: provider, endpointURL: Constants.Enjin.apiUrl)

        return ApolloClient(networkTransport: transport, store: store)
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

final private class NetworkInterceptorProvider: InterceptorProvider {
    // These properties will remain the same throughout the life of the `InterceptorProvider`, even though they
    // will be handed to different interceptors.
    private let store: ApolloStore
    private let client: URLSessionClient
    private let enjinUserManagementInterceptor: EnjinUserManagementInterceptor

    init(store: ApolloStore, client: URLSessionClient) {
        self.store = store
        self.client = client
        self.enjinUserManagementInterceptor = EnjinUserManagementInterceptor(store: store, client: client)
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        return [
            MaxRetryInterceptor(),
            CacheReadInterceptor(store: store),
            enjinUserManagementInterceptor,
            NetworkFetchInterceptor(client: client),
            ResponseCodeInterceptor(),
            JSONResponseParsingInterceptor(cacheKeyForObject: store.cacheKeyForObject),
            AutomaticPersistedQueryInterceptor(),
            CacheWriteInterceptor(store: store)
        ]
    }
}

