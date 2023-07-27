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
    //TODO reduce usage and remove
    func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError>
    func dataTask(_ request: URLRequestConvertible) async throws -> URLRequest.Response
    //TODO reduce usage and remove
    func responseTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<HTTPURLResponse, SessionTaskError>
}

public typealias RetryPolicy = Alamofire.RetryPolicy
public final class ApiTransporterRetryPolicy: RetryPolicy {

    public override func retry(_ request: Alamofire.Request,
                               for session: Session,
                               dueTo error: Error,
                               completion: @escaping (RetryResult) -> Void) {

        if request.retryCount < retryLimit, shouldRetry(request: request, dueTo: error) {
            if let httpResponse = request.response, let delay = ApiTransporterRetryPolicy.retryDelay(from: httpResponse) {
                completion(.retryWithDelay(delay))
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

extension ApiTransporterRetryPolicy {
    public convenience init() {
        self.init(retryableHTTPStatusCodes: [429, 408, 500, 502, 503, 504])
    }
}

public class BaseApiTransporter: ApiTransporter {

    private let rootQueue = DispatchQueue(label: "org.alamofire.customQueue")
    private let session: Session

    var maxPublishers: Int = 3//max concurrent tasks

    public init(timeout: TimeInterval = 60, policy: RetryPolicy = ApiTransporterRetryPolicy()) {

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = true

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
        Just(request)
            .setFailureType(to: SessionTaskError.self)
            .flatMap(maxPublishers: .max(maxPublishers)) { [session, rootQueue] request in
                session.request(request)
                    .validate()
                    .publishData(queue: rootQueue)
                    .tryMap { respose in
                        if let data = respose.data, let httpResponse = respose.response {
                            return (data: data, response: httpResponse)
                        } else if let error = respose.error {
                            throw SessionTaskError(error: error)
                        } else {
                            throw SessionTaskError(error: NonHttpUrlResponseError(request: request))
                        }
                    }.mapError { SessionTaskError(error: $0) }
            }.eraseToAnyPublisher()
    }

    public func dataTask(_ request: URLRequestConvertible) async throws -> URLRequest.Response {
        let response = try await session.request(request).serializingData().response
        if let data = response.data, let response = response.response {
            return (data, response)
        } else {
            throw SessionTaskError(error: NonHttpUrlResponseError(request: request))
        }
    }

    public func responseTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<HTTPURLResponse, SessionTaskError> {
        Just(request)
            .setFailureType(to: SessionTaskError.self)
            .flatMap(maxPublishers: .max(maxPublishers)) { [session, rootQueue] request in
                session.request(request)
                    .validate()
                    .publishData(queue: rootQueue)
                    .tryMap { respose in
                        if let httpResponse = respose.response {
                            return httpResponse
                        } else {
                            throw SessionTaskError(error: NonHttpUrlResponseError(request: request))
                        }
                    }.mapError { SessionTaskError(error: $0) }

            }.eraseToAnyPublisher()
    }
}
