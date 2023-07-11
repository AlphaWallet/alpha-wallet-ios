//
//  Uniswap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.08.2020.
//

import Foundation
import Combine

public struct Uniswap: SupportedTokenActionsProvider, SwapTokenViaUrlProvider {
    public var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    public let action: String

    public func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer? {
        return .main
    }

    public let analyticsNavigation: Analytics.Navigation = .onUniswap
    public let analyticsName: String = "Uniswap"

    private static let baseURL = "https://app.uniswap.org/#"

    var version: Version = .v2
    var theme: Theme = .dark
    var method: Method = .swap

    public func url(token: TokenActionsIdentifiable) -> URL? {
        let input = Input.input(token.contractAddress)
        var components = URLComponents()
        components.path = method.rawValue
        components.queryItems = [
            URLQueryItem(name: Version.key, value: version.rawValue),
            URLQueryItem(name: Theme.key, value: theme.rawValue)
        ] + input.urlQueryItems

        //NOTE: URLComponents doesn't allow path to contain # symbol
        guard let pathWithQueryItems = components.url?.absoluteString else { return nil }

        return URL(string: Uniswap.baseURL + pathWithQueryItems)
    }

    enum Version: String {
        static let key = "use"

        case v1
        case v2
    }

    public enum Theme: String {
        static let key = "theme"

        case dark
        case light
    }

    enum Method: String {
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
                    //Uniswap likes it this way
                    return "ETH"
                } else {
                    return address.eip55String
                }
            }
        }
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [
            .init(type: .swap(service: self))
        ]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return UniswapERC20Token.isSupport(token: token)
    }

    public func start() {
        //no-op
    }
}
