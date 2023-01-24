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

extension URLRequest {
    public typealias Response = (data: Data, response: HTTPURLResponse)
}

public protocol NetworkService {
    func dataTaskPublisher(_ request: URLRequestConvertible, callbackQueue: DispatchQueue) -> AnyPublisher<URLRequest.Response, SessionTaskError>
    func upload(multipartFormData: @escaping (MultipartFormData) -> Void, usingThreshold: UInt64, to url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders?, callbackQueue: DispatchQueue) -> AnyPublisher<Alamofire.DataResponse<Any>, SessionTaskError>
}

extension NetworkService {
    func dataTaskPublisher(_ request: URLRequestConvertible) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
        dataTaskPublisher(request, callbackQueue: .main)
    }

    func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                usingThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
                to url: URLConvertible,
                method: HTTPMethod = .post,
                headers: HTTPHeaders? = nil,
                callbackQueue: DispatchQueue = .main) -> AnyPublisher<Alamofire.DataResponse<Any>, SessionTaskError> {
        upload(
            multipartFormData: multipartFormData,
            usingThreshold: usingThreshold,
            to: url,
            method: method,
            headers: headers,
            callbackQueue: callbackQueue)
    }

}

public class BaseNetworkService: NetworkService {
    private let analytics: AnalyticsLogger
    private let session: SessionManager

    public init(analytics: AnalyticsLogger, configuration: URLSessionConfiguration = .default) {
        self.session = SessionManager(configuration: configuration)
        self.analytics = analytics
    }

    public func upload(
        multipartFormData: @escaping (MultipartFormData) -> Void,
        usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshold,
        to url: URLConvertible,
        method: HTTPMethod = .post,
        headers: HTTPHeaders? = nil,
        callbackQueue: DispatchQueue) -> AnyPublisher<Alamofire.DataResponse<Any>, SessionTaskError> {

            return AnyPublisher<Alamofire.DataResponse<Any>, SessionTaskError>.create { [session, callbackQueue] seal in
                var urlRequest: UploadRequest?

                session.upload(
                    multipartFormData: multipartFormData,
                    usingThreshold: encodingMemoryThreshold,
                    to: url,
                    method: method,
                    headers: headers,
                    encodingCompletion: { result in
                        switch result {
                        case .success(let request, let streamingFromDisk, let streamFileURL):
                            urlRequest = request.responseJSON(queue: callbackQueue, completionHandler: {
                                seal.send($0)
                                seal.send(completion: .finished)
                            })
                        case .failure(let error):
                            seal.send(completion: .failure(.requestError(error)))
                        }
                    })

                return AnyCancellable {
                    urlRequest?.cancel()
                }
            }
    }

    public func dataTaskPublisher(_ request: URLRequestConvertible, callbackQueue: DispatchQueue) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
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

struct NonHTTPURLResponseError: Error {
    let response: HTTPURLResponse?
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
            return .failure(.responseError(NonHTTPURLResponseError(response: response.response)))
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

extension JSONEncoding {
    public func encode(_ urlRequest: URLRequestConvertible, codable: Codable) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()

        do {
            let data = try JSONEncoder().encode(codable)

            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }

        return urlRequest
    }
}
