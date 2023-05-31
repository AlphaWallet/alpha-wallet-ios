//
//  NetworkService.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.12.2022.
//

import Foundation
import Alamofire
import Combine
import AlphaWalletCore

public typealias URLRequestConvertible = Alamofire.URLRequestConvertible
public typealias URLEncoding = Alamofire.URLEncoding
public typealias JSONEncoding = Alamofire.JSONEncoding
public typealias Parameters = Alamofire.Parameters
public typealias HTTPHeaders = Alamofire.HTTPHeaders
public typealias HTTPMethod = Alamofire.HTTPMethod
public typealias MultipartFormData = Alamofire.MultipartFormData

extension URLRequest {
    public typealias Response = (data: Data, response: HTTPURLResponse)
}

extension URLRequest {
    public static func validate<S: Sequence>(statusCode acceptableStatusCodes: S,
                                             response: HTTPURLResponse) -> Alamofire.Request.ValidationResult where S.Iterator.Element == Int {

        if acceptableStatusCodes.contains(response.statusCode) {
            return .success(())
        } else {
            let reason = AFError.ResponseValidationFailureReason.unacceptableStatusCode(code: response.statusCode)
            return .failure(AFError.responseValidationFailed(reason: reason))
        }

    }
}

public protocol NetworkService {
    func dataTask(_ request: URLRequestConvertible) async throws -> URLRequest.Response
    func dataTaskPublisher(_ request: URLRequestConvertible, callbackQueue: DispatchQueue) -> AnyPublisher<URLRequest.Response, SessionTaskError>
    func upload(multipartFormData: @escaping (MultipartFormData) -> Void, usingThreshold: UInt64, with request: URLRequestConvertible, callbackQueue: DispatchQueue) -> AnyPublisher<URLRequest.Response, SessionTaskError>
}

extension NetworkService {
    func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
        dataTaskPublisher(request, callbackQueue: .main)
    }

    func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                with request: URLRequestConvertible,
                callbackQueue: DispatchQueue = .main) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
        upload(
            multipartFormData: multipartFormData,
            usingThreshold: encodingMemoryThreshold,
            with: request,
            callbackQueue: callbackQueue)
    }

}

public class BaseNetworkService: NetworkService {
    private let analytics: AnalyticsLogger
    private let session: Session

    public init(analytics: AnalyticsLogger, configuration: URLSessionConfiguration = .default) {
        self.session = Session(configuration: configuration)
        self.analytics = analytics
    }

    public func upload(
        multipartFormData: @escaping (MultipartFormData) -> Void,
        usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
        with request: URLRequestConvertible,
        callbackQueue: DispatchQueue) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
            return session.upload(multipartFormData: multipartFormData, with: request)
                .publishData(queue: callbackQueue)
                .tryMap {
                    if let data = $0.data, let response = $0.response {
                        return (data, response)
                    } else {
                        throw NonHTTPURLResponseError(error: $0.error)
                    }
                }.mapError { SessionTaskError.requestError($0) }
                .eraseToAnyPublisher()
    }

    public func dataTaskPublisher(_ request: URLRequestConvertible,
                                  callbackQueue: DispatchQueue) -> AnyPublisher<URLRequest.Response, SessionTaskError> {

        return session.request(request)
            .publishData(queue: callbackQueue)
            .tryMap {
                if let data = $0.data, let response = $0.response {
                    return (data, response)
                } else {
                    throw NonHTTPURLResponseError(error: $0.error)
                }
            }.mapError { SessionTaskError.requestError($0) }
            .eraseToAnyPublisher()
    }

    public func dataTask(_ request: URLRequestConvertible) async throws -> URLRequest.Response {
        let response = try await session.request(request).serializingData().response
        if let data = response.data, let response = response.response {
            return (data, response)
        } else {
            throw NonHTTPURLResponseError(error: response.error)
        }
    }

}

extension BaseNetworkService {
    enum functional {}
}

struct NonHTTPURLResponseError: Error {
    let error: AFError?
}
extension JSONEncoding {
    public func encode(_ urlRequest: URLRequestConvertible, codable: Codable) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()

        do {
            let data = try JSONEncoder().encode(codable)

            if urlRequest.headers["Content-Type"] == nil {
                urlRequest.headers.update(.contentType("application/json"))
            }

            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }

        return urlRequest
    }
}
