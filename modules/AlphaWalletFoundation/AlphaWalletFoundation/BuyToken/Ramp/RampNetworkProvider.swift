//
//  RampNetworkProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 19.09.2022.
//

import Foundation
import AlphaWalletCore
import Combine

public protocol RampNetworkProviderType {
    func retrieveAssets() -> AnyPublisher<[Asset], PromiseError>
}

public final class RampNetworkProvider: RampNetworkProviderType {
    private let decoder = JSONDecoder()
    private let networkService: NetworkService

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    public func retrieveAssets() -> AnyPublisher<[Asset], PromiseError> {
        return networkService
            .dataTaskPublisher(RampRequest())
            .tryMap { [decoder] in try decoder.decode(RampAssetsResponse.self, from: $0.data).assets }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }
}
//NOTE: internal because we use it also for debugging
extension RampNetworkProvider {
    struct RampRequest: URLRequestConvertible { 

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.Ramp.exchangeUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/host-api/assets"
            let url = try components.asURL()
            return try URLRequest(url: url, method: .get)
        }
    }
}
