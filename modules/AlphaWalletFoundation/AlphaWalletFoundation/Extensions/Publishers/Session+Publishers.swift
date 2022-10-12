//
//  Session+Publishers.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation
import APIKit
import JSONRPCKit
import Combine

extension APIKitSession {

    class func sendPublisher<Request: APIKit.Request>(_ request: Request, server: RPCServer, analytics: AnalyticsLogger, callbackQueue: CallbackQueue? = nil) -> AnyPublisher<Request.Response, SessionTaskError> {
        sendImplPublisher(request, server: server, callbackQueue: callbackQueue)
            .retry(times: 2, when: {
                guard case SessionTaskError.requestError(let e) = $0 else { return false }
                if let e = e as? RpcNodeRetryableRequestError {
                    logRpcNodeError(e, analytics: analytics)
                }
                return e is RpcNodeRetryableRequestError
            }).eraseToAnyPublisher()
    }

    private static func logRpcNodeError(_ rpcNodeError: RpcNodeRetryableRequestError, analytics: AnalyticsLogger) {
        switch rpcNodeError {
        case .rateLimited(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeRateLimited, properties: [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName])
        case .invalidApiKey(let server, let domainName):
            analytics.log(error: Analytics.WebApiErrors.rpcNodeInvalidApiKey, properties: [Analytics.Properties.chain.rawValue: server.chainID, Analytics.Properties.domainName.rawValue: domainName])
        case .possibleBinanceTestnetTimeout, .networkConnectionWasLost, .invalidCertificate, .requestTimedOut:
            return
        }
    }

    private class func sendImplPublisher<Request: APIKit.Request>(_ request: Request, server: RPCServer, callbackQueue: CallbackQueue? = nil) -> AnyPublisher<Request.Response, SessionTaskError> {
        var sessionTask: SessionTask?
        let publisher = Deferred {
            Future<Request.Response, SessionTaskError> { seal in
                sessionTask = APIKitSession.send(request, callbackQueue: callbackQueue) { result in
                    switch result {
                    case .success(let result):
                        seal(.success(result))
                    case .failure(let error):
                        if let e = convertToUserFriendlyError(error: error, server: server, baseUrl: request.baseURL) {
                            seal(.failure(.requestError(e)))
                        } else {
                            seal(.failure(error))
                        }
                    }
                }
            }
        }.handleEvents(receiveCancel: {
            sessionTask?.cancel()
        })

        return publisher
            .eraseToAnyPublisher()
    }
}
