//
//  BaseOneinchNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 19.09.2022.
//

import Foundation
import AlphaWalletCore
import Combine

public protocol OneinchNetworking {
    func retrieveAssets() -> AnyPublisher<[Oneinch.Asset], PromiseError>
}

public final class BaseOneinchNetworking: OneinchNetworking {
    private let decoder = JSONDecoder()
    private let networkService: NetworkService

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    public func retrieveAssets() -> AnyPublisher<[Oneinch.Asset], PromiseError> {
        return networkService
            .dataTaskPublisher(OneInchAssetsRequest())
            .receive(on: DispatchQueue.global())
            .tryMap { [decoder] in try decoder.decode(Oneinch.AssetsResponse.self, from: $0.data).tokens.map { $0.value } }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }
}

extension BaseOneinchNetworking {
    struct OneInchAssetsRequest: URLRequestConvertible {
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.OneInch.exchangeUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v3.0/1/tokens"

            return try URLRequest(url: try components.asURL(), method: .get)
        }
    }
}
