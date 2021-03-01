//
//  Uniswap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.08.2020.
//

import UIKit

struct Uniswap: SwapTokenActionsService, SwapTokenURLProviderType {

    var action: String {
        return R.string.localizable.aWalletTokenErc20ExchangeOnUniswapButtonTitle()
    }
    var rpcServer: RPCServer? {
        .main
    }

    var analyticsName: String {
        "Uniswap"
    }

    private static let baseURL = "https://app.uniswap.org/#"

    var version: Version = .v2
    var theme: Theme = .dark
    var method: Method = .swap

    func url(token: TokenObject) -> URL? {
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

    enum Theme: String {
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

        case inputOutput(from: AlphaWallet.Address, to: AddressOrEnsName)
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

    func actions(token: TokenObject) -> [TokenInstanceAction] {
        return [
            .init(type: .swap(service: self))
        ]
    }

    func isSupport(token: TokenObject) -> Bool {
        return UniswapERC20Token.isSupport(token: token)
    }
}

extension UITraitCollection {
    var uniswapTheme: Uniswap.Theme {
        if #available(iOS 12.0, *) {
            switch userInterfaceStyle {
            case .dark:
                return .dark
            case .light, .unspecified:
                return .light
            }
        } else {
            return .light
        }
    }
}
