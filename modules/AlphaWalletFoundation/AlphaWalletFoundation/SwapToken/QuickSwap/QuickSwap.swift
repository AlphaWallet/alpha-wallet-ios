//
//  QuickSwap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.08.2020.
//

import Foundation
import Combine

public class QuickSwap: SupportedTokenActionsProvider, SwapTokenViaUrlProvider {
    public var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    public let action: String

    public func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer? {
        return .polygon
    }
    public let analyticsNavigation: Analytics.Navigation = .onQuickSwap
    public let analyticsName: String = "QuickSwap"

    private static let baseURL = "https://quickswap.exchange/#"

    public var version: Version = .v2
    public var theme: Uniswap.Theme = .dark
    public var method: Method = .swap

    public func url(token: TokenActionsIdentifiable) -> URL? {
        let input = Input.input(token.contractAddress)
        var components = URLComponents()
        components.path = method.rawValue
        components.queryItems = [
            URLQueryItem(name: Version.key, value: version.rawValue),
            URLQueryItem(name: Uniswap.Theme.key, value: theme.rawValue)
        ] + input.urlQueryItems

        //NOTE: URLComponents doesn't allow path to contain # symbol
        guard let pathWithQueryItems = components.url?.absoluteString else { return nil }

        return URL(string: QuickSwap.baseURL + pathWithQueryItems)
    }

    public enum Version: String {
        static let key = "use"

        case v1
        case v2
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
                    .init(name: Keys.input, value: functional.rewriteContractInput(inputAddress)),
                    .init(name: Keys.output, value: outputAddress.stringValue),
                ]
            case .input(let address):
                return [
                    .init(name: Keys.input, value: functional.rewriteContractInput(address))
                ]
            case .none:
                return []
            }
        }

        enum functional {
            static func rewriteContractInput(_ address: AlphaWallet.Address) -> String {
                if address == Constants.nativeCryptoAddressInDatabase {
                    //QuickSwap (forked from Uniswap) likes it this way
                    return "ETH"
                } else {
                    return address.eip55String
                }
            }
        }
    }

    public init(action: String) {
        self.action = action
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [
            .init(type: .swap(service: self))
        ]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        switch token.server.serverWithEnhancedSupport {
        case .polygon:
            return true
        case .main, .xDai, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return false
        }
    }

    public func start() {
        //no-op
    }
}
