//
//  QuickSwap.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.08.2020.
//

import Foundation

struct QuickSwap: TokenActionsProvider, SwapTokenURLProviderType {

    var action: String {
        return R.string.localizable.aWalletTokenErc20ExchangeOnQuickSwapButtonTitle()
    }

    func rpcServer(forToken token: TokenActionsServiceKey) -> RPCServer? {
        return .polygon
    }

    var analyticsName: String {
        "QuickSwap"
    }

    private static let baseURL = "https://quickswap.exchange/#"

    var version: Version = .v2
    var theme: Uniswap.Theme = .dark
    var method: Method = .swap

    func url(token: TokenActionsServiceKey) -> URL? {
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

    enum Version: String {
        static let key = "use"

        case v1
        case v2
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

        class functional {
            static func rewriteContractInput(_ address: AlphaWallet.Address) -> String {
                if address.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                    //QuickSwap (forked from Uniswap) likes it this way
                    return "ETH"
                } else {
                    return address.eip55String
                }
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
        case .polygon:
            return true
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .xDai, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return false
        }
    }
}
