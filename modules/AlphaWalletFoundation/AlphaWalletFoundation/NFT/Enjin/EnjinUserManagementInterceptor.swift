//
//  EnjinAuthorization.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 05.11.2021.
//

import AlphaWalletCore
import AlphaWalletLogger
import Apollo
import PromiseKit

public typealias EnjinAccessToken = String
public typealias EnjinCredentials = (email: String, password: String)
public protocol EnjinAccessTokenStore {
    func accessToken(email: String) -> EnjinAccessToken?
    func set(accessToken: EnjinAccessToken?, email: String)
}

class EnjinUserManager {
    private let store: ApolloStore
    private let client: URLSessionClient
    private let endpointURL: URL
    private let credentials: EnjinCredentials?

    let accessTokenStore: EnjinAccessTokenStore

    init(store: ApolloStore,
         client: URLSessionClient,
         accessTokenStore: EnjinAccessTokenStore,
         endpointURL: URL,
         credentials: EnjinCredentials?) {

        self.credentials = credentials
        self.endpointURL = endpointURL
        self.store = store
        self.client = client
        self.accessTokenStore = accessTokenStore
    }

    var accessToken: EnjinAccessToken? {
        guard let credentials = credentials else { return nil }
        return accessTokenStore.accessToken(email: credentials.email)
    }

    private lazy var graphqlClient: ApolloClient = {
        let provider = InterceptorProviderForAuthorization(client: client, store: store)
        let transport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: endpointURL)

        return ApolloClient(networkTransport: transport, store: store)
    }()

    enum EnjinUserManagerError: Error {
        case fetchAccessTokenFailure
        case credentialsNotFound
    }

    func enjinAuthorize() -> Promise<EnjinAccessToken> {
        guard let credentials = credentials else {
            return .init(error: EnjinUserManagementInterceptor.UserError.usersCredentialsNotFound)
        }

        return EnjinUserManager.functional.authorize(graphqlClient: graphqlClient, email: credentials.email, password: credentials.password).map { oauth -> EnjinAccessToken in
            if let accessToken = oauth.accessTokens?.compactMap({ $0 }).first {
                return accessToken
            } else {
                throw EnjinUserManagerError.fetchAccessTokenFailure
            }
        }.get { accessToken in
            self.accessTokenStore.set(accessToken: accessToken, email: credentials.email)
        }.recover { [credentials] e -> Promise<EnjinAccessToken> in
            infoLog("[Enjin] authorization failure: \(e.localizedDescription)")
            self.accessTokenStore.set(accessToken: .none, email: credentials.email)
            throw e
        }
    }

    private class InterceptorProviderForAuthorization: DefaultInterceptorProvider {
        private let client: URLSessionClient
        private let store: ApolloStore

        public init(client: URLSessionClient, store: ApolloStore) {
            self.client = client
            self.store = store

            super.init(client: client, shouldInvalidateClientOnDeinit: true, store: store)
        }

        open override func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
            return [
                MaxRetryInterceptor(),
                CacheReadInterceptor(store: store),
                NetworkFetchInterceptor(client: client),
                ResponseCodeInterceptor(),
                FallbackJSONResponseParsingInterceptor(cacheKeyForObject: store.cacheKeyForObject),
                AutomaticPersistedQueryInterceptor(),
                CacheWriteInterceptor(store: store),
            ]
        }
    }
}

/// Fallback decader for parsing response for EnjinAuth as its couldn't be performed with default method
struct FallbackJSONResponseParsingInterceptor: ApolloInterceptor {

    public enum JSONResponseParsingError: Error, LocalizedError {
        case noResponseToParse
        case couldNotParseToJSON(data: Data)
        case caseToAvoidAuthDecodingError(body: JSONObject)

        public var errorDescription: String? {
            switch self {
            case .noResponseToParse:
                return "The Codable Parsing Interceptor was called before a response was received to be parsed. Double-check the order of your interceptors."
            case .caseToAvoidAuthDecodingError:
                return "Special case for failure deciding EnjinAuth object"
            case .couldNotParseToJSON(let data):
                var errorStrings = [String]()
                errorStrings.append("Could not parse data to JSON format.")
                if let dataString = String(bytes: data, encoding: .utf8) {
                    errorStrings.append("Data received as a String was:")
                    errorStrings.append(dataString)
                } else {
                    errorStrings.append("Data of count \(data.count) also could not be parsed into a String.")
                }

                return errorStrings.joined(separator: " ")
            }
        }
    }

    public let cacheKeyForObject: CacheKeyForObject?

        /// Designated Initializer
    public init(cacheKeyForObject: CacheKeyForObject? = nil) {
        self.cacheKeyForObject = cacheKeyForObject
    }

    public func interceptAsync<Operation: GraphQLOperation>(chain: RequestChain,
                                                            request: HTTPRequest<Operation>,
                                                            response: HTTPResponse<Operation>?,
                                                            completion: @escaping (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void) {

        guard let createdResponse = response else {
            chain.handleErrorAsync(JSONResponseParsingError.noResponseToParse, request: request, response: response, completion: completion)
            return
        }

        do {
            guard let body = try JSONSerializationFormat.deserialize(data: createdResponse.rawData) as? JSONObject else {
                throw JSONResponseParsingError.couldNotParseToJSON(data: createdResponse.rawData)
            }

            let graphQLResponse = GraphQLResponse(operation: request.operation, body: body)
            createdResponse.legacyResponse = graphQLResponse

            if createdResponse is HTTPResponse<EnjinOauthQuery> {
                chain.handleErrorAsync(JSONResponseParsingError.caseToAvoidAuthDecodingError(body: body), request: request, response: createdResponse, completion: completion)
            } else {
                let result = try parseResult(from: graphQLResponse, cachePolicy: request.cachePolicy)
                createdResponse.parsedResponse = result

                chain.proceedAsync(request: request, response: createdResponse, completion: completion)
            }
        } catch {
            chain.handleErrorAsync(error, request: request, response: createdResponse, completion: completion)
        }
    }

    private func parseResult<Data>(from response: GraphQLResponse<Data>, cachePolicy: CachePolicy) throws -> GraphQLResult<Data> {
        switch cachePolicy {
        case .fetchIgnoringCacheCompletely:
            // There is no cache, so we don't need to get any info on dependencies. Use fast parsing.
            return try response.parseResultFast()
        default:
            let (parsedResult, _) = try response.parseResult(cacheKeyForObject: self.cacheKeyForObject)
            return parsedResult
        }
    }

}

final actor EnjinUserManagementInterceptor: ApolloInterceptor {

    enum UserError: Error {
        case noUserLoggedIn
        case usersCredentialsNotFound
    }

    private let userManager: EnjinUserManager
    private var pending: [() -> Void] = []
    private var inFlightPromise: Promise<EnjinAccessToken>?

    init(userManager: EnjinUserManager) {
        self.userManager = userManager
    }

    nonisolated func interceptAsync<Operation: GraphQLOperation>(chain: RequestChain, request: HTTPRequest<Operation>, response: HTTPResponse<Operation>?, completion: @escaping (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void) {
        Task {
            await _interceptAsync(chain: chain, request: request, response: response, completion: completion)
        }
    }

    private func _interceptAsync<Operation: GraphQLOperation>(chain: RequestChain, request: HTTPRequest<Operation>, response: HTTPResponse<Operation>?, completion: @escaping (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void) {
        func addTokenAndProceed<Operation: GraphQLOperation>(_ token: EnjinAccessToken, to request: HTTPRequest<Operation>, chain: RequestChain, response: HTTPResponse<Operation>?, completion: @escaping (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void) {

            request.addHeader(name: "Authorization", value: "Bearer \(token)")
            chain.proceedAsync(request: request, response: response, completion: completion)
        }

        let authorizeEnjinUser: () -> Void = { [userManager] in
            let performAuthorizeEnjinUser: () -> Void = { [userManager] in
                let promise = userManager.enjinAuthorize()
                promise.done { accessToken in
                    addTokenAndProceed(accessToken, to: request, chain: chain, response: response, completion: completion)
                }.catch { error in
                    chain.handleErrorAsync(error, request: request, response: response, completion: completion)
                }.finally {
                    self.pending.forEach { action in action() }
                    self.pending.removeAll()
                }

                self.inFlightPromise = promise
            }

            if let promise = self.inFlightPromise {
                if let accessToken = promise.value {
                    addTokenAndProceed(accessToken, to: request, chain: chain, response: response, completion: completion)
                } else if promise.isPending {
                    //NOTE: wait until access token resolved
                    let block: () -> Void = {
                        guard let accessToken = userManager.accessToken else { return }
                        addTokenAndProceed(accessToken, to: request, chain: chain, response: response, completion: completion)
                    }
                    self.pending.append(block)
                } else {
                    performAuthorizeEnjinUser()
                }
            } else {
                performAuthorizeEnjinUser()
            }
        }

        let overridenCompletion: (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void = { result in
            switch result {
            case .failure(let error):
                if let error = error as? ResponseCodeInterceptor.ResponseCodeError {
                    switch error {
                    case .invalidResponseCode(let response, _):
                        if response?.statusCode == 401 {
                            authorizeEnjinUser()
                        } else {
                            completion(result)
                        }
                    }
                } else {
                    completion(result)
                }
            case .success:
                completion(result)
            }
        }

        guard let accessToken = userManager.accessToken else {
            authorizeEnjinUser()
            return
        }

        addTokenAndProceed(accessToken, to: request, chain: chain, response: response, completion: overridenCompletion)
    }
}

extension EnjinUserManager {
    enum functional { }
}

fileprivate extension EnjinUserManager.functional {
    private struct EnjinOauthFallbackDecoder {
        func decode(from body: JSONObject) -> EnjinOauthQuery.Data.EnjinOauth? {
            guard let data = body["data"] as? [String: Any], let authData = data["EnjinOauth"] as? [String: Any] else { return nil }
            guard let name = authData["name"] as? String else { return nil }
            guard let tokensJsons = authData["accessTokens"] as? [[String: Any]] else { return nil }

            let tokens = tokensJsons.compactMap { json in
                return json["accessToken"] as? String
            }
            guard !tokens.isEmpty else { return nil }
            return EnjinOauthQuery.Data.EnjinOauth(name: name, accessTokens: tokens)
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
                        let error = EnjinError(localizedDescription: "Enjin authorization failure")
                        return seal.reject(error)
                    }

                    seal.fulfill(data)
                }
            }
        }
    }
}
