//
//  HoneySwap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.02.2021.
//

import UIKit

class HoneySwap: TokenActionsProvider, SwapTokenURLProviderType {

    var action: String {
        return R.string.localizable.aWalletTokenErc20ExchangeHoneyswapButtonTitle()
    }
    //NOTE: While selection on action browser will be automatically switched to defined server `rpcServer`
    func rpcServer(forToken token: TokenActionsServiceKey) -> RPCServer? {
        return .xDai
    }

    var analyticsName: String {
        "Honeyswap"
    }

    private static let baseURL = "https://app.honeyswap.org/#"

    var version: Version = .v2
    var theme: Theme = .dark
    var method: Method = .swap

    func url(token: TokenActionsServiceKey) -> URL? {
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

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        return [
            .init(type: .swap(service: self))
        ]
    }

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        switch token.server {
        case .xDai:
            return true
        case .main, .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .custom, .poa, .callisto, .classic, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return false
        }
    }
}

extension UITraitCollection {
    var honeyswapTheme: HoneySwap.Theme {
        switch userInterfaceStyle {
        case .dark:
            return .dark
        case .light, .unspecified:
            return .light
        }
    }
}
