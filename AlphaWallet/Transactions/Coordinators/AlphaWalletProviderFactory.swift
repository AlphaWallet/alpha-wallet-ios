// Copyright SIX DAY LLC. All rights reserved.

import Alamofire
import Foundation
import Moya
import PromiseKit 
import Combine

struct AlphaWalletProviderFactory {
    static let policies: [String: ServerTrustPolicy] = [:]

    static func makeProvider() -> MoyaProvider<AlphaWalletService> {
        let manager = Manager(
            configuration: URLSessionConfiguration.default,
            serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies)
        )
        var plugins: [PluginType] = []

        if Features.default.isAvailable(.shouldPrintCURLForOutgoingRequest) {
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

enum PromiseError: Error {
    case some(error: Error)
}

extension Promise {
    var publisher: AnyPublisher<T, PromiseError> {
        var isCanceled: Bool = false
        let publisher = Deferred {
            Future<T, PromiseError> { seal in
                guard !isCanceled else { return }
                let queue = DispatchQueue.global(qos: .userInitiated)

                self.done(on: queue, { value in
                    seal(.success((value)))
                }).catch(on: queue, { error in
                    seal(.failure(.some(error: error)))
                })
            }
        }.handleEvents(receiveCancel: {
            isCanceled = true
        })

        return publisher
            .eraseToAnyPublisher()
    }
}
