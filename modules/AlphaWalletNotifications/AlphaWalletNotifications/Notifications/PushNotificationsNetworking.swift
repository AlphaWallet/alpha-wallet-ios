//
//  PushNotificationsNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.04.2023.
//

import Foundation
import AlphaWalletCore
import Combine
import AlphaWalletFoundation

public typealias PushNotificationSubscription = String

public protocol PushNotificationsNetworking {
    func subscriptions() -> AnyPublisher<[AlphaWallet.Address: PushNotificationSubscription], SessionTaskError>
    func subscribe(walletAddress: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Bool, Never>
    func unsubscribe(walletAddress: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Bool, Never>
}

public class BasePushNotificationsNetworking: PushNotificationsNetworking {
    private let transporter: ApiTransporter
    private let baseUrl: URL? = nil
    private let apiKey: String?

    public init(transporter: ApiTransporter, apiKey: String?) {
        self.transporter = transporter
        self.apiKey = apiKey
    }

    public func subscriptions() -> AnyPublisher<[AlphaWallet.Address: PushNotificationSubscription], SessionTaskError> {
        guard let baseUrl = baseUrl else { return .empty() }
        let request = SubscriptionsRequest(
            baseUrl: baseUrl,
            apiKey: apiKey)

        return transporter.responseTaskPublisher(request)
            .tryMap { _ in return [:] }
            .mapError { SessionTaskError(error: $0) }
            .eraseToAnyPublisher()
    }

    enum ResponseError: Error {
        case invalidStatusCode(Int)
    }

    public func subscribe(walletAddress: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Bool, Never> {
        guard let baseUrl = baseUrl else { return .empty() }

        let request = SubscribeRequest(
            baseUrl: baseUrl,
            wallet: walletAddress,
            server: server,
            apiKey: apiKey)

        return transporter.responseTaskPublisher(request)
            .map { $0.statusCode == 201 }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }

    public func unsubscribe(walletAddress: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Bool, Never> {
        guard let baseUrl = baseUrl else { return .empty() }
        //TODO: unsubscribe api doesn't work for not

        /*
        let request = UnsubscribeRequest(
            baseUrl: baseUrl,
            wallet: walletAddress,
            server: server,
            apiKey: apiKey)

        return transporter.responseTaskPublisher(request)
            .map { $0.statusCode == 201 }
            .replaceError(with: false)
            .eraseToAnyPublisher()
         */
        return .just(true)
    }

    private struct SubscriptionsRequest: URLRequestConvertible {
        let baseUrl: URL
        let apiKey: String?

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/notification/subscriptions"
            var headers = HTTPHeaders([
                "User-Agent": "Chrome/74.0.3729.169",
                "Content-Type": "application/json"
            ])
            if let apiKey = apiKey, apiKey.nonEmpty {
                headers.add(name: "X-API-KEY", value: apiKey)
            }

            return try URLRequest(url: components.asURL(), method: .get, headers: headers)
        }
    }

    private struct SubscribeRequest: URLRequestConvertible {
        let baseUrl: URL
        let wallet: AlphaWallet.Address
        let server: RPCServer
        let apiKey: String?

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/notification/subscriptions"
            var headers = HTTPHeaders([
                "User-Agent": "Chrome/74.0.3729.169"
            ])

            if let apiKey = apiKey, apiKey.nonEmpty {
                headers.add(name: "X-API-KEY", value: apiKey)
            }
            let request = try URLRequest(url: components.asURL(), method: .post, headers: headers)

            return try JSONEncoding().encode(request, with: [
               "wallet": wallet.eip55String,
               "chainId": server.chainID
           ])
        }
    }

    private struct UnsubscribeRequest: URLRequestConvertible {
        let baseUrl: URL
        let wallet: AlphaWallet.Address
        let server: RPCServer
        let apiKey: String?

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/notification/subscriptions/\(wallet.eip55String)/\(server.chainID)"

            var headers = HTTPHeaders([
                "User-Agent": "Chrome/74.0.3729.169"
            ])

            if let apiKey = apiKey, apiKey.nonEmpty {
                headers.add(name: "X-API-KEY", value: apiKey)
            }
            let request = try URLRequest(url: components.asURL(), method: .delete, headers: headers)

            return try JSONEncoding().encode(request, with: nil)
        }
    }
}
