//
//  HoneySwap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.02.2021.
//

import Foundation
import Combine

public class HoneySwap: SupportedTokenActionsProvider, SwapTokenViaUrlProvider {
    public var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    public let action: String
    //NOTE: While selection on action browser will be automatically switched to defined server `rpcServer`
    public func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer? {
        return .xDai
    }
    public let analyticsNavigation: Analytics.Navigation = .onHoneyswap
    public let analyticsName: String = "Honeyswap"

    private static let baseURL = "https://app.honeyswap.org/#"

    public var version: Version = .v2
    public var theme: Theme = .dark
    public var method: Method = .swap

    public func url(token: TokenActionsIdentifiable) -> URL? {
        var components = URLComponents()
        components.path = method.rawValue
        components.queryItems = [
            URLQueryItem(name: Version.key, value: version.rawValue),
            URLQueryItem(name: Theme.key, value: theme.rawValue)
        ]

        //NOTE: URLComponents doesn't allow path to contain # symbol
        guard let pathWithQueryItems = components.url?.absoluteString else { return nil }

        return URL(string: HoneySwap.baseURL + pathWithQueryItems)
    }

    public enum Version: String {
        static let key = "use"

        case v1
        case v2
    }

    public enum Theme: String {
        static let key = "theme"

        case dark
        case light
    }

    public enum Method: String {
        case swap = "/swap"
        case use
    }

    enum Input {
        enum Keys {
            static let input = "inputCurrency"
            static let output = "outputCurrency"
        }

        case inputOutput(from: AlphaWallet.Address, to: AddressOrDomainName)
        case input(AlphaWallet.Address)
        case none

        var urlQueryItems: [URLQueryItem] {
            switch self {
            case .inputOutput(let inputAddress, let outputAddress):
                return [
                    .init(name: Keys.input, value: inputAddress.eip55String),
                    .init(name: Keys.output, value: outputAddress.stringValue),
                ]
            case .input(let address):
                return [
                    .init(name: Keys.input, value: address.eip55String)
                ]
            case .none:
                return []
            }
        }
    }

    public init(action: String) {
        self.action = action
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .swap(service: self))]
    }

    public func start() {
        //no-op
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        switch token.server.serverWithEnhancedSupport {
        case .xDai:
            return true
        case .main, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return false
        }
    }
}
