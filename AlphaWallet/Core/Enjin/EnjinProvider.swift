//
//  EnjinProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.10.2021.
//

import Foundation
import Apollo
import PromiseKit 

struct EnjinError: Error {
    var localizedDescription: String
}

class EnjinProvider {

    private class WeakRef<T: AnyObject> {
        weak var object: T?
        init(object: T) {
            self.object = object
        }
    }

    typealias PromiseResult = Promise<[AlphaWallet.Address: [GetEnjinTokenQuery.Data.EnjinToken]]>

    private static let numberOfTokenIdsBeforeRateLimitingRequests = 25
    private static let minimumSecondsBetweenRequests = TimeInterval(60)

    private(set) lazy var graphqlClient: ApolloClient = {
        let client = URLSessionClient()
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)
        let provider = NetworkInterceptorProvider(store: store, client: client)
        let transport = RequestChainNetworkTransport(interceptorProvider: provider, endpointURL: Constants.enjinApiUrl)
        return ApolloClient(networkTransport: transport, store: store)
    }()

    private static var instances = [AddressAndRPCServer: WeakRef<EnjinProvider>]()
    //NOTE: using AddressAndRPCServer fixes issue with incorrect tokens returned from makeFetchPromise
    // the problem was that cached OpenSea returned tokens from multiple wallets
    private let key: AddressAndRPCServer
    private var recentWalletsWithManyTokens = [AlphaWallet.Address: (Date, PromiseResult)]()
    private var fetch = EnjinProvider.makeEmptyFulfilledPromise()
    private let queue = DispatchQueue.global(qos: .userInitiated)

    private init(key: AddressAndRPCServer) {
        self.key = key
    }

    static func createInstance(with key: AddressAndRPCServer) -> EnjinProvider {
        if let instance = instances[key]?.object {
            return instance
        } else {
            let instance = EnjinProvider(key: key)
            instances[key] = WeakRef(object: instance)
            return instance
        }
    }

    private static func makeEmptyFulfilledPromise() -> PromiseResult {
        return Promise {
            $0.fulfill([:])
        }
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main:
            return true
        case .rinkeby, .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
            return false
        }
    }

    static func resetInstances() {
        for each in instances.values {
            each.object?.reset()
        }
    }

    ///Call this after switching wallets, otherwise when the current promise is fulfilled, the switched to wallet will think the API results are for them
    private func reset() {
        fetch = EnjinProvider.makeEmptyFulfilledPromise()
    }

    ///Uses a promise to make sure we don't fetch from OpenSea multiple times concurrently
    func makeFetchPromise() -> PromiseResult {
        guard OpenSea.isServerSupported(key.server) else {
            fetch = .value([:])
            return fetch
        }
        let owner = key.address
        trimCachedPromises()
        if let cachedPromise = cachedPromise(forOwner: owner) {
            return cachedPromise
        }

        if fetch.isResolved {
            fetch = Promise<MappedEnjinBalances> { seal in
                let offset = 1
                fetchPage(forOwner: owner, offset: offset) { result in
                    switch result {
                    case .success(let result):
                        seal.fulfill(result)
                    case .failure(let error):
                        seal.reject(error)
                    }
                }
            }.then({ balances -> Promise<[AlphaWallet.Address: [GetEnjinTokenQuery.Data.EnjinToken]]> in
                let ids = (balances[owner] ?? []).compactMap { $0.token?.id }
                return EnjinProvider.functional.getTokens(graphqlClient: self.graphqlClient, ids: ids, owner: owner)
            })
        }
        return fetch
    }

    typealias EnjinBalances = [GetEnjinBalancesQuery.Data.EnjinBalance]
    typealias MappedEnjinBalances = [AlphaWallet.Address: EnjinBalances]

    private func fetchPage(forOwner owner: AlphaWallet.Address, offset: Int, completion: @escaping (Swift.Result<MappedEnjinBalances, EnjinError>) -> Void) {
        EnjinProvider.functional.fetchPage(graphqlClient: graphqlClient, forOwner: owner, offset: offset) { [weak self] response in
            switch response {
            case .success(let result):
                self?.cachePromise(withTokenIdCount: result.tokenIdCount, forOwner: result.owner)
                completion(.success(result.excludingUefa))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func cachePromise(withTokenIdCount tokenIdCount: Int, forOwner wallet: AlphaWallet.Address) {
        guard tokenIdCount >= EnjinProvider.numberOfTokenIdsBeforeRateLimitingRequests else { return }
        recentWalletsWithManyTokens[wallet] = (Date(), fetch)
    }

    private func cachedPromise(forOwner wallet: AlphaWallet.Address) -> PromiseResult? {
        guard let (_, promise) = recentWalletsWithManyTokens[wallet] else { return nil }
        return promise
    }

    private func trimCachedPromises() {
        let cachedWallets = recentWalletsWithManyTokens.keys
        let now = Date()
        for each in cachedWallets {
            guard let (date, _) = recentWalletsWithManyTokens[each] else { continue }
            if now.timeIntervalSince(date) >= EnjinProvider.minimumSecondsBetweenRequests {
                recentWalletsWithManyTokens.removeValue(forKey: each)
            }
        }
    }
}

extension EnjinProvider {
    enum functional { }
}

extension EnjinProvider.functional {

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

    typealias FetchEnjinTokensResponse = (excludingUefa: EnjinProvider.MappedEnjinBalances, tokenIdCount: Int, owner: AlphaWallet.Address)

    fileprivate static func fetchPage(graphqlClient: ApolloClient, forOwner owner: AlphaWallet.Address, offset: Int, sum: EnjinProvider.MappedEnjinBalances = [:], limit: Int = 50, completion: @escaping (Swift.Result<FetchEnjinTokensResponse, EnjinError>) -> Void) {

        graphqlClient.fetch(query: GetEnjinBalancesQuery(ethAddress: owner.eip55String, page: offset, limit: limit)) { response in
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
                    fetchPage(graphqlClient: graphqlClient, forOwner: owner, offset: offset + 1, sum: results) { results in
                        completion(results)
                    }
                } else {
                    let excludingUefa = sum
                    var tokenIdCount = 0
                    for (_, tokenIds) in excludingUefa {
                        tokenIdCount += tokenIds.count
                    }

                    completion(.success((excludingUefa, tokenIdCount, owner)))
                }
            }
        }
    }

    fileprivate static func getTokens(graphqlClient: ApolloClient, ids: [String], owner: AlphaWallet.Address) -> Promise<[AlphaWallet.Address: [GetEnjinTokenQuery.Data.EnjinToken]]> {
        if ids.isEmpty {
            return .value([owner: []])
        }
        
        let promises = ids.compactMap({ tokenId in
            return Promise<GetEnjinTokenQuery.Data.EnjinToken> { seal in
                graphqlClient.fetch(query: GetEnjinTokenQuery(id: tokenId)) { response in
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
        })

        return when(resolved: promises).map { results in
            let tokens = results.compactMap { $0.optionalValue }
            return [owner: tokens]
        }
    }
}

final class NetworkInterceptorProvider: InterceptorProvider {
    // These properties will remain the same throughout the life of the `InterceptorProvider`, even though they
    // will be handed to different interceptors.
    private let store: ApolloStore
    private let client: URLSessionClient

    init(store: ApolloStore, client: URLSessionClient) {
        self.store = store
        self.client = client
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        return [
            MaxRetryInterceptor(),
            CacheReadInterceptor(store: self.store),
            UserManagementInterceptor(),
            NetworkFetchInterceptor(client: self.client),
            ResponseCodeInterceptor(),
            JSONResponseParsingInterceptor(cacheKeyForObject: self.store.cacheKeyForObject),
            AutomaticPersistedQueryInterceptor(),
            CacheWriteInterceptor(store: self.store)
        ]
    }
}

