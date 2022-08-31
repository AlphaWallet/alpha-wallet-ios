// Copyright SIX DAY LLC. All rights reserved.

import Alamofire
import Foundation
import Moya
import PromiseKit 
import Combine
import AlphaWalletCore

public struct AlphaWalletProviderFactory {
    static let policies: [String: ServerTrustPolicy] = [:]

    public static func makeProvider() -> MoyaProvider<AlphaWalletService> {
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
    public func request(_ target: Target, callbackQueue: DispatchQueue? = .none, progress: ProgressBlock? = .none) -> Promise<Moya.Response> {
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

extension MoyaProvider {
    public func publisher(_ target: Target, callbackQueue: DispatchQueue? = .none, progress: ProgressBlock? = .none) -> AnyPublisher<Moya.Response, MoyaError> {
        var cancelable: Moya.Cancellable?
        let publisher = Deferred {
            Future<Moya.Response, MoyaError> { [self] seal in
                cancelable = self.request(target, callbackQueue: callbackQueue, progress: progress) { result in
                    switch result {
                    case .success(let response):
                        seal(.success(response))
                    case .failure(let error):
                        seal(.failure(error))
                    }
                }
            }
        }.handleEvents(receiveCancel: {
            cancelable?.cancel()
        })

        return publisher
            .eraseToAnyPublisher()
    }
}

extension Promise {
    public var publisher: AnyPublisher<T, PromiseError> {
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
