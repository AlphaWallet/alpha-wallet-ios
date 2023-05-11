//
//  MediaContentNetworking.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2023.
//

import Foundation
import Alamofire
import AlphaWalletFoundation
import Combine
import AlphaWalletOpenSea

protocol MediaContentNetworking {
    func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError>
}

public class MediaContentNetworkingImpl: MediaContentNetworking {

    private let rootQueue = DispatchQueue(label: "org.alamofire.customQueue")
    private let session: Session

    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true

        let policy = RetryPolicy(retryLimit: 3)

        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in
            DispatchQueue.main.async { /*no-op*/ }
        }

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 10
        queue.underlyingQueue = rootQueue

        let delegate = Alamofire.SessionDelegate()
        let urlSession = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: queue)

        session = Session(
            session: urlSession,
            delegate: delegate,
            rootQueue: rootQueue,
            interceptor: policy,
            eventMonitors: [monitor])
    }

    struct NonHttpUrlResponseError: Error {
        let request: URLRequestConvertible
    }

    public func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
        session.request(request)
            .validate()
            .publishData(queue: rootQueue)
            .tryMap { respose in
                if let data = respose.data, let httpResponse = respose.response {
                    return (data: data, response: httpResponse)
                } else {
                    throw SessionTaskError.responseError(NonHttpUrlResponseError(request: request))
                }
            }.mapError { SessionTaskError.responseError($0) }
            .eraseToAnyPublisher()
    }
}
