//
//  NetworkService.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.12.2022.
//

import Foundation
import Alamofire
import Combine
import PromiseKit
import AlphaWalletCore
import APIKit

public typealias URLRequestConvertible = Alamofire.URLRequestConvertible
public typealias URLEncoding = Alamofire.URLEncoding
public typealias Parameters = Alamofire.Parameters
public typealias JSONEncoding = Alamofire.JSONEncoding
public typealias HTTPHeaders = Alamofire.HTTPHeaders

public typealias ResponseError = APIKit.ResponseError

extension URLRequest {
    public typealias Response = (data: Data, response: HTTPURLResponse)
}

public protocol NetworkService {
    func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError>
    func dataTaskPromise(_ request: URLRequestConvertible) -> Promise<URLRequest.Response>
}

public class BaseNetworkService: NetworkService {
    private let analytics: AnalyticsLogger
    private let session: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()

    public var callbackQueue: DispatchQueue

    public init(analytics: AnalyticsLogger, callbackQueue: DispatchQueue = .global()) {
        self.analytics = analytics
        self.callbackQueue = callbackQueue
    }

    public func dataTaskPromise(_ request: URLRequestConvertible) -> Promise<URLRequest.Response> {
        return Promise<URLRequest.Response>.init { [session, callbackQueue] seal in
            let urlRequest: URLRequest
            do {
                urlRequest = try request.asURLRequest()
            } catch {
                seal.reject(SessionTaskError.requestError(error))
                return
            }

            session
                .request(urlRequest)
                .response(queue: callbackQueue, completionHandler: { response in
                    switch BaseNetworkService.functional.decode(response: response) {
                    case .success(let value):
                        seal.fulfill(value)
                    case .failure(let error):
                        seal.reject(error)
                    }
                })
        }
    }

    public func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
        var cancellable: DataRequest?
        return Deferred { [session, callbackQueue] in
            Future<URLRequest.Response, SessionTaskError> { seal in
                let urlRequest: URLRequest
                do {
                    urlRequest = try request.asURLRequest()
                } catch {
                    seal(.failure(.requestError(error)))
                    return
                }

                cancellable = session
                    .request(urlRequest)
                    .response(queue: callbackQueue, completionHandler: { response in
                        switch BaseNetworkService.functional.decode(response: response) {
                        case .success(let value):
                            seal(.success(value))
                        case .failure(let error):
                            seal(.failure(error))
                        }
                    })
            }
        }.handleEvents(receiveCancel: { cancellable?.cancel() })
        .eraseToAnyPublisher()
    }

}

extension BaseNetworkService {
    class functional {}
}

extension BaseNetworkService.functional {
    static func decode(response: DefaultDataResponse) -> Swift.Result<URLRequest.Response, SessionTaskError> {
        switch (response.data, response.response, response.error) {
        case (_, _, let error?):
            return .failure(.connectionError(error))
        case (let data?, let urlResponse as HTTPURLResponse, _):
            do {
                return .success((data: data as Data, response: urlResponse))
            } catch {
                return .failure(.responseError(error))
            }
        default:
            return .failure(.responseError(ResponseError.nonHTTPURLResponse(response.response)))
        }
    }
}

public protocol AnyDecoder {
    var contentType: String? { get }

    func decode(response: HTTPURLResponse, data: Data) throws -> Any
}

extension AnyDecoder {
    func decode(options: JSONSerialization.ReadingOptions = [], _ response: URLRequest.Response) throws -> Any {
        try decode(response: response.response, data: response.data)
    }
}

public struct AnyJsonDecoder: AnyDecoder {
    public var contentType: String? {
        return "application/json"
    }

    let options: JSONSerialization.ReadingOptions

    public func decode(response: HTTPURLResponse, data: Data) throws -> Any {
        switch Alamofire.Request.serializeResponseJSON(options: options, response: response, data: data, error: nil) {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

struct RawDataParser: AnyDecoder {
    var contentType: String? {
        "application/json"
    }

    func decode(response: HTTPURLResponse, data: Data) throws -> Any {
        return data
    }
}

