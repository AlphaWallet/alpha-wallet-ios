//
//  UniswapHolder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.08.2020.
//

import UIKit

struct UniswapHolder {
    private static let baseURL = "https://app.uniswap.org/#"

    let input: Input
    var version: Version = .v2
    var theme: Theme = .dark
    var method: Method = .swap

    var url: URL? {
        var components = URLComponents()
        components.path = method.rawValue
        components.queryItems = [
            URLQueryItem(name: Version.key, value: version.rawValue),
            URLQueryItem(name: Theme.key, value: theme.rawValue)
        ] + input.urlQueryItems

        //NOTE: URLComponents doesn't allow path to contain # symbol
        guard let pathWithQueryItems = components.url?.absoluteString else { return nil }

        return URL(string: UniswapHolder.baseURL + pathWithQueryItems)
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
        private enum Keys {
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
}

