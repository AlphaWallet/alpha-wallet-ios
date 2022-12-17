//
//  RpcNetworkService.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 03.03.2023.
//

import Combine
import BigInt
import AlphaWalletWeb3
import AlphaWalletCore
import AlphaWalletLogger
import Alamofire

public protocol RpcNetworkService {
    func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError>
}

public class BaseRpcNetworkService: RpcNetworkService {
    private let callCounter = CallCounter()
    private let rootQueue = DispatchQueue(label: "org.alamofire.customQueue")
    private let session: Session

    public var maxPublishers: Int = 10

    public init(server: RPCServer) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true

        let policy = RpcRetryPolicy()

        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { [callCounter, server] request, _ in
            DispatchQueue.main.async {
                callCounter.clock()
                let url = request.lastRequest?.url?.absoluteString
                infoLog("[Rpc \(server.name)] Accessing url: \(url) rate: \(callCounter.averageRatePerSecond)/sec")
            }
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

    private struct NonHttpUrlResponseError: Error {
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
                        } else {
                            throw NonHttpUrlResponseError(request: request)
                        }
                    }.mapError { SessionTaskError(error: $0) }
            }.eraseToAnyPublisher()
    }
}

final class RpcRetryPolicy: RetryPolicy {

    init() {
        var retryableHttpMethods = RetryPolicy.defaultRetryableHTTPMethods
        retryableHttpMethods.insert(.post)

        super.init(retryableHTTPMethods: retryableHttpMethods, retryableHTTPStatusCodes: Set([429, 408, 500, 502, 503, 504]))
    }

    override func retry(_ request: Alamofire.Request,
                        for session: Session,
                        dueTo error: Error,
                        completion: @escaping (RetryResult) -> Void) {

        if request.retryCount < retryLimit, shouldRetry(request: request, dueTo: error) {
            if let request = request as? DataRequest, let data = request.data, let backoffSeconds = RpcRetryPolicy.backoffSeconds(from: data) {
                completion(.retryWithDelay(TimeInterval(backoffSeconds)))
            } else {
                completion(.retryWithDelay(pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale))
            }
        } else {
            completion(.doNotRetry)
        }
    }

    private static func backoffSeconds(from data: Data) -> Int? {
        do {
            let response = try JSONDecoder().decode(RpcResponseBatch.self, from: data)
            if let error = response.responses.compactMap { $0.error?.data }.first, let rateLimitted = try? error.get(RateLimitedResponse.self) {
                return rateLimitted.rate.backoff_seconds
            }
        } catch {
            do {
                let response = try JSONDecoder().decode(RpcResponse.self, from: data)
                if let data = response.error?.data, let rateLimitted = try? data.get(RateLimitedResponse.self) {
                    return rateLimitted.rate.backoff_seconds
                }
            } catch { /*no-op*/ }
        }
        return nil
    }
}

fileprivate class CallCounter {
    //Just to be safe, not too big
    private static let maximumSize = 1000

    private static let windowInSeconds = 10

    private var calledAtTimes = [Int]()
    private var edge: Int {
        let currentTime = Int(Date().timeIntervalSince1970)
        return currentTime - Self.windowInSeconds
    }

    var averageRatePerSecond: Double {
        var total: Int = 0

        //TODO reversed might be much faster? But we are truncating already
        for each in calledAtTimes where each >= edge {
            total += 1
        }
        let result: Double = Double(total) / Double(Self.windowInSeconds)
        return result
    }

    func clock() {
        calledAtTimes.append(Int(Date().timeIntervalSince1970))
        if calledAtTimes.count > Self.maximumSize {
            if let i = calledAtTimes.firstIndex(where: { $0 >= edge }) {
                calledAtTimes = Array(calledAtTimes.dropFirst(i))
            }
        }
    }
}

public struct RateLimitedResponse: Codable {
    public let rate: RateLimited
    public let see: String

    public init(rate: RateLimited, see: String) {
        self.rate = rate
        self.see = see
    }
}

public struct RateLimited: Codable {
    public let allowed_rps: Int
    public let backoff_seconds: Int
    public let current_rps: Double

    public init(allowed_rps: Int, backoff_seconds: Int, current_rps: Double) {
        self.allowed_rps = allowed_rps
        self.backoff_seconds = backoff_seconds
        self.current_rps = current_rps
    }
}
