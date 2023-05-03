//
//  ApiTransporter.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 28.02.2023.
//

import Foundation
import Alamofire
import Combine

public protocol ApiTransporter {
    func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError>
    func dataPublisher(_ request: URLRequestConvertible) -> AnyPublisher<DataResponsePublisher<Data>.Output, SessionTaskError>
}

final class ApiTransporterRetryPolicy: RetryPolicy {
    private let timeout: TimeInterval

    init(timeout: TimeInterval) {
        self.timeout = timeout
        super.init(retryableHTTPStatusCodes: Set([429, 408, 500, 502, 503, 504]))
    }

    override func retry(_ request: Alamofire.Request,
                        for session: Session,
                        dueTo error: Error,
                        completion: @escaping (RetryResult) -> Void) {
        let d = request.cURLDescription()
        if d.contains("api.coingeck") {
            print("xxx.retry for \(request.cURLDescription()) error: \(error)")
        }

        if request.retryCount < retryLimit, shouldRetry(request: request, dueTo: error) {
            if let httpResponse = request.response, let delay = ApiTransporterRetryPolicy.retryDelay(from: httpResponse) {
                if delay <= timeout {
                    completion(.retryWithDelay(delay))
                } else {
                    completion(.doNotRetry)
                }
            } else {
                completion(.retryWithDelay(pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale))
            }
        } else {
            completion(.doNotRetry)
        }
    }

    private static func retryDelay(from httpResponse: HTTPURLResponse) -> TimeInterval? {
        (httpResponse.allHeaderFields["retry-after"] as? String).flatMap { TimeInterval($0) }
    }
}

public class BaseApiTransporter: ApiTransporter {

    private let rootQueue = DispatchQueue(label: "org.alamofire.customQueue")
    private let session: Session
    private let timeout: TimeInterval

    var maxPublishers: Int = 10//max concurrent tasks

    public init(timeout: TimeInterval = 60) {
        self.timeout = timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = true

        let policy = ApiTransporterRetryPolicy(timeout: timeout)

        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { _, _ in
            DispatchQueue.main.async { /*no-op*/ }
        }

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.underlyingQueue = rootQueue

        let delegate = SessionDelegate()
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
        return Just(request)
            .setFailureType(to: SessionTaskError.self)
            .flatMap(maxPublishers: .max(maxPublishers)) { [session, rootQueue] request in
                return session.request(request)
                    .validate()
                    .publishData(queue: rootQueue)
                    .tryMap { respose in
                        if let data = respose.data, let httpResponse = respose.response {
                            return (data: data, response: httpResponse)
                        } else {
                            throw SessionTaskError(error: NonHttpUrlResponseError(request: request))
                        }
                    }.mapError { SessionTaskError(error: $0) }
            }.eraseToAnyPublisher()
    }

    public func dataPublisher(_ request: URLRequestConvertible) -> AnyPublisher<DataResponsePublisher<Data>.Output, SessionTaskError> {
        Just(request)
            .setFailureType(to: SessionTaskError.self)
            .flatMap(maxPublishers: .max(maxPublishers)) { [session, rootQueue] request in
                session.request(request)
                    .validate()
                    .publishData(queue: rootQueue)
                    .mapError { SessionTaskError(error: $0) }
            }.eraseToAnyPublisher()
    }
}
