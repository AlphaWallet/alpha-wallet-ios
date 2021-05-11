// Copyright SIX DAY LLC. All rights reserved.

import Alamofire
import Foundation
import Moya
import PromiseKit

struct AlphaWalletProviderFactory {
    static let policies: [String: ServerTrustPolicy] = [:]
    
    static func makeProvider() -> MoyaProvider<AlphaWalletService> {
        let manager = Manager(
            configuration: URLSessionConfiguration.default,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )
        var plugins: [PluginType] = []

        if Features.shouldPrintCURLForOutgoingRequest {
            plugins.append(NetworkLoggerPlugin(cURL: true))
        }

        return MoyaProvider<AlphaWalletService>(manager: manager, plugins: plugins)
    }
}

extension MoyaProvider {
    func request(_ target: Target, callbackQueue: DispatchQueue? = .none, progress: ProgressBlock? = .none) -> Promise<Moya.Response> {
        Promise { seal in
            request(target, callbackQueue: callbackQueue, progress: progress) { result in
                switch result {
                case .success(let response):
                    seal.fulfill(response)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}

func attempt<T>(maximumRetryCount: Int = 3, delayBeforeRetry: DispatchTimeInterval = .seconds(1), _ body: @escaping () -> Promise<T>) -> Promise<T> {
    var attempts = 0
    func attempt() -> Promise<T> {
        attempts += 1

        return body().recover { error -> Promise<T> in
            guard attempts < maximumRetryCount else {
                throw error
            }

            if case PMKError.cancelled = error {
                throw error
            }

            return after(delayBeforeRetry).then(on: nil, attempt)
        }
    }

    return attempt()
}
