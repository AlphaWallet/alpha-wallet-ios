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
public typealias Parameters = Alamofire.Parameters
public typealias JSONEncoding = Alamofire.JSONEncoding
public typealias HTTPHeaders = Alamofire.HTTPHeaders

public protocol NetworkService {
    func responseData(_ request: URLRequestConvertible) -> AnyPublisher<(data: Data, response: AlphaWalletCore.DataResponse), PromiseError>
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

}
