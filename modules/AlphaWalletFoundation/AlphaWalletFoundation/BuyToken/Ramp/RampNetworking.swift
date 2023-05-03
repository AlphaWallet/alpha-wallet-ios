//
//  RampNetworkProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 19.09.2022.
//

import Foundation
import AlphaWalletCore
import Combine

public protocol RampNetworking {
    func retrieveAssets() -> AnyPublisher<[Asset], PromiseError>
}

public final class BaseRampNetworking: RampNetworking {
    private let decoder = JSONDecoder()
    private let networkService: NetworkService

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    public func retrieveAssets() -> AnyPublisher<[Asset], PromiseError> {
        return networkService
            .dataTaskPublisher(RampRequest())
            .receive(on: DispatchQueue.global())
            .tryMap { [decoder] in try decoder.decode(RampAssetsResponse.self, from: $0.data).assets }
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }
}
//NOTE: internal because we use it also for debugging
extension BaseRampNetworking {
    struct RampRequest: URLRequestConvertible { 

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.Ramp.exchangeUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/host-api/assets"
            let url = try components.asURL()
            return try URLRequest(url: url, method: .get)
        }
    }
}
