//
//  EnjinAuthorization.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 05.11.2021.
//

import Apollo
import PromiseKit

typealias AccessToken = String
extension Config {
    fileprivate static let accessTokenKey = "AccessTokenKey"

    var accessToken: AccessToken? {
        get {
            defaults.value(forKey: Self.accessTokenKey) as? AccessToken
        }
        set {
            guard let value = newValue else {
                return defaults.removeObject(forKey: Self.accessTokenKey)
            }
            defaults.set(value, forKey: Self.accessTokenKey)
        }
    }
}

class UserManager {
    static let shared = UserManager()
    private init() {
    }
    private var config = Config()

    private let graphqlClient: ApolloClient = {
        let client = URLSessionClient()
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)
        let provider = InterceptorProviderForAuthorization(client: client, store: store)

        let transport = RequestChainNetworkTransport(interceptorProvider: provider, endpointURL: Constants.enjinApiUrl)
        return ApolloClient(networkTransport: transport, store: store)
    }()

    enum UserManagerError: Error {
        case fetchAccessTokenFailure
    }

    var accessToken: AccessToken? { config.accessToken }

    private let email: String = Constants.Credentials.enjinUserName
    private let password: String = Constants.Credentials.enjinUserPassword

    func enjinAuthorize() -> Promise<AccessToken> {
        enjinAuthorize(email: email, password: password)
    }

    private func enjinAuthorize(email: String, password: String) -> Promise<AccessToken> {
        return EnjinProvider.functional.authorize(graphqlClient: graphqlClient, email: email, password: password).map { oauth -> AccessToken in
            if let accessToken = oauth.accessTokens?.compactMap({ $0 }).first {
                return accessToken
            } else {
                throw UserManagerError.fetchAccessTokenFailure
            }
        }.get { accessToken in
            self.config.accessToken = accessToken
        }.recover { e -> Promise<AccessToken> in
            self.config.accessToken = .none
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
                CacheReadInterceptor(store: self.store),
                NetworkFetchInterceptor(client: self.client),
                ResponseCodeInterceptor(),
                FallbackJSONResponseParsingInterceptor(cacheKeyForObject: self.store.cacheKeyForObject),
                AutomaticPersistedQueryInterceptor(),
                CacheWriteInterceptor(store: self.store),
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

    public func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
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

class UserManagementInterceptor: ApolloInterceptor {

    enum UserError: Error {
        case noUserLoggedIn
    }

    private static var pending: [() -> Void] = []
    private static var promise: Promise<AccessToken>?

    func interceptAsync<Operation: GraphQLOperation>(chain: RequestChain, request: HTTPRequest<Operation>, response: HTTPResponse<Operation>?, completion: @escaping (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void) {

        func addTokenAndProceed<Operation: GraphQLOperation>(_ token: AccessToken, to request: HTTPRequest<Operation>, chain: RequestChain, response: HTTPResponse<Operation>?, completion: @escaping (Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void) {

            request.addHeader(name: "Authorization", value: "Bearer \(token)")
            chain.proceedAsync(request: request, response: response, completion: completion)
        }

        let performAuthorizeEnjinUser: () -> Void = {
            let promise = UserManager.shared.enjinAuthorize()
            promise.done { accessToken in
                addTokenAndProceed(accessToken, to: request, chain: chain, response: response, completion: completion)
            }.catch { error in
                chain.handleErrorAsync(error, request: request, response: response, completion: completion)
            }.finally {
                Self.pending.forEach { action in action() }
                Self.pending.removeAll()
            }

            Self.promise = promise
        }

        let authorizeEnjinUser: () -> Void = {
            if let promise = Self.promise {
                if let accessToken = promise.value {
                    addTokenAndProceed(accessToken, to: request, chain: chain, response: response, completion: completion)
                } else if promise.isPending {
                     //NOTE: wait until access token resolved
                    let block: () -> Void = {
                        guard let accessToken = UserManager.shared.accessToken else { return }
                        addTokenAndProceed(accessToken, to: request, chain: chain, response: response, completion: completion)
                    }
                    Self.pending.append(block)
                } else {
                    performAuthorizeEnjinUser()
                }
            } else {
                performAuthorizeEnjinUser()
            }
        }

        let overridenCompletion: ((Swift.Result<GraphQLResult<Operation.Data>, Error>) -> Void) = { result in
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

        guard let token = UserManager.shared.accessToken else {
            return authorizeEnjinUser()
        }

        addTokenAndProceed(token, to: request, chain: chain, response: response, completion: overridenCompletion)
    }
}
