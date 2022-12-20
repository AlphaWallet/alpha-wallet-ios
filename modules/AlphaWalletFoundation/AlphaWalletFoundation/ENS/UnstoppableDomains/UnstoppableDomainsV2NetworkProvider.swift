//
//  UnstoppableDomainsV2NetworkProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 23.09.2022.
//

import Combine
import SwiftyJSON
import AlphaWalletENS
import AlphaWalletCore

struct UnstoppableDomainsV2NetworkProvider {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func resolveDomain(address: AlphaWallet.Address) -> AnyPublisher<String, PromiseError> {
        return networkService
            .dataTaskPublisher(DomainRequest(address: address))
            .tryMap { response -> String in
                guard let json = try? JSON(data: response.data) else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(Constants.unstoppableDomainsV2API.absoluteString) API isMainThread: \(Thread.isMainThread)")
                }

                let value = try UnstoppableDomainsV2Resolver.DomainResolution.Response(json: json)
                if let record = value.data.first {
                    infoLog("[UnstoppableDomains] resolved address: \(address.eip55String) result: \(record.id)")
                    return record.id
                } else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(Constants.unstoppableDomainsV2API.absoluteString) API isMainThread: \(Thread.isMainThread)")
                }
            }.mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    func resolveAddress(forName name: String) -> AnyPublisher<AlphaWallet.Address, PromiseError> {
        return networkService
            .dataTaskPublisher(AddressRequest(name: name))
            .tryMap { response -> AlphaWallet.Address in
                guard let json = try? JSON(data: response.data) else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(Constants.unstoppableDomainsV2API.absoluteString) API isMainThread: \(Thread.isMainThread)")
                }

                let value = try UnstoppableDomainsV2Resolver.AddressResolution.Response(json: json)
                if let owner = value.meta.owner {
                    infoLog("[UnstoppableDomains] resolved name: \(name) result: \(owner.eip55String)")
                    return owner
                } else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(Constants.unstoppableDomainsV2API.absoluteString) API isMainThread: \(Thread.isMainThread)")
                }
            }.mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }

    private struct AddressRequest: URLRequestConvertible {
        let name: String

        public func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.unstoppableDomainsV2API, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/domains/\(name)"

            let request = try URLRequest(url: components.asURL(), method: .get)
            return request.appending(httpHeaders: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
        }
    }

    private struct DomainRequest: URLRequestConvertible {
        let address: AlphaWallet.Address

        public func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.unstoppableDomainsV2API, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/domains/"

            var request = try URLRequest(url: components.asURL(), method: .get)

            return try URLEncoding().encode(request, with: [
                "owners": address.eip55String,
                "sortBy": "id",
                "sortDirection": "DESC",
                "perPage": 50
            ]).appending(httpHeaders: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
        }
    }
}
