//
//  OneinchNetworkProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 19.09.2022.
//

import Foundation
import AlphaWalletCore
import Combine
import Alamofire

public protocol OneinchNetworkProviderType {
    func retrieveAssets() -> AnyPublisher<[Oneinch.Asset], PromiseError>
}

public final class OneinchNetworkProvider: OneinchNetworkProviderType {
    private let decoder = JSONDecoder()

    public init() { }
    public func retrieveAssets() -> AnyPublisher<[Oneinch.Asset], PromiseError> {
        let request = OneInchAssetsRequest()
        return Alamofire.request(request)
            .responseDataPublisher()
            .tryMap { [decoder] in try decoder.decode(Oneinch.AssetsResponse.self, from: $0.data).tokens.map { $0.value } }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private struct OneInchAssetsRequest: URLRequestConvertible {
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.OneInch.exchangeUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v3.0/1/tokens"
            let url = try components.asURL()
            return try URLRequest(url: url, method: .get)
        }
    }
}
