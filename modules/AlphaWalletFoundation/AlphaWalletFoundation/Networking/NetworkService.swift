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

public typealias URLRequestConvertible = Alamofire.URLRequestConvertible
public typealias URLEncoding = Alamofire.URLEncoding
public typealias Parameters = Alamofire.Parameters
public typealias JSONEncoding = Alamofire.JSONEncoding
public typealias HTTPHeaders = Alamofire.HTTPHeaders

public protocol NetworkService {
    func responseData(_ request: URLRequestConvertible) -> AnyPublisher<(data: Data, response: AlphaWalletCore.DataResponse), PromiseError>
    //FIXME: get rid of promise version, need for now to avoid a lot files changing
    func responseData(_ uri: URL, queue: DispatchQueue?) -> Promise<(data: Data, response: AlphaWalletCore.DataResponse)>
}

public final class BaseNetworkService: NetworkService {
    private let analytics: AnalyticsLogger

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    public func responseData(_ request: URLRequestConvertible) -> AnyPublisher<(data: Data, response: AlphaWalletCore.DataResponse), PromiseError> {
        Alamofire.request(request)
            .validate()
            .responseDataPublisher()
            //TODO: add logging rate limit and the rest errors
    }

    public func responseData(_ uri: URL, queue: DispatchQueue?) -> Promise<(data: Data, response: AlphaWalletCore.DataResponse)> {
        Alamofire.request(uri, method: .get)
            .validate()
            .responseDataPromise(queue: queue)
    }
}

public class NoHeadersNetworkService: NetworkService {
    private let analytics: AnalyticsLogger
    private var sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    public func responseData(_ request: URLRequestConvertible) -> AnyPublisher<(data: Data, response: AlphaWalletCore.DataResponse), PromiseError> {
        sessionManagerWithDefaultHttpHeaders
            .request(request)
            .responseDataPublisher()
            //TODO: add logging rate limit and the rest errors
    }

    public func responseData(_ uri: URL, queue: DispatchQueue?) -> Promise<(data: Data, response: AlphaWalletCore.DataResponse)> {
        //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
        sessionManagerWithDefaultHttpHeaders
            .request(uri, method: .get)
            .responseDataPromise(queue: queue)
    }
}

public protocol AnyDecoder {
    func decode(options: JSONSerialization.ReadingOptions, response: HTTPURLResponse?, data: Data?) throws -> Any
}

extension AnyDecoder {
    func decode(options: JSONSerialization.ReadingOptions = [], _ response: (data: Data, response: AlphaWalletCore.DataResponse)) throws -> Any {
        try decode(options: options, response: response.response.response, data: response.data)
    }
}

public struct AnyJsonDecoder: AnyDecoder {
    public func decode(options: JSONSerialization.ReadingOptions = [], response: HTTPURLResponse?, data: Data?) throws -> Any {
        switch Alamofire.Request.serializeResponseJSON(options: options, response: response, data: data, error: nil) {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
