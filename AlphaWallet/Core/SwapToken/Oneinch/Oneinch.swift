//
//  OneinchHolder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation
import PromiseKit
import Moya

class Oneinch: SwapTokenActionsService, SwapTokenURLProviderType {

    var action: String {
        return R.string.localizable.aWalletTokenErc20ExchangeOn1inchButtonTitle()
    }

    private static let baseURL = "https://1inch.exchange/#"
    private static let refferal = "/r/0x98f21584006c79871F176F8D474958a69e04595B"
    //NOTE: for Oneinch exchange service we need to use two addresses, by default it uses Uptrennd token
    private static let outputAddress = AlphaWallet.Address(string: "0x07597255910a51509ca469568b048f2597e72504")!
    private let predefinedTokens: [Oneinch.ERC20Token] = [
        .init(symbol: "ETH", name: "ETH", address: Constants.nativeCryptoAddressInDatabase, decimal: 18)
    ]

    private(set) var availableTokens: [Oneinch.ERC20Token] = []

    func url(token: TokenObject) -> URL? {
        guard isSupportToken(token: token) else { return nil }

        var components = URLComponents()
        components.path = Oneinch.refferal + "/" + subpath(inputAddress: token.contractAddress)
        //NOTE: URLComponents doesn't allow path to contain # symbol
        guard let pathWithQueryItems = components.url?.absoluteString else { return nil }

        return URL(string: Oneinch.baseURL + pathWithQueryItems)
    }

    private func subpath(inputAddress: AlphaWallet.Address) -> String {
        return [token(address: inputAddress), token(address: Oneinch.outputAddress)].compactMap {
            $0?.symbol
        }.joined(separator: "/")
    }

    func actions(token: TokenObject) -> [TokenInstanceAction] {
        if self.isSupport(token: token) {
            return [
                .init(type: .swap(service: self))
            ]
        } else {
            return []
        }
    }

    private func isSupport(token: TokenObject) -> Bool {
        switch token.server {
        case .main:
            return availableTokens.contains(where: { $0.address == token.contractAddress })
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .custom, .poa, .callisto, .xDai, .classic, .binance_smart_chain, .binance_smart_chain_testnet:
            return false
        }
    }

    private func token(address: AlphaWallet.Address) -> Oneinch.ERC20Token? {
        return availableTokens.first(where: { $0.address == address })
    }

    func fetchSupportedTokens() {
        let config = Config()
        let provider = AlphaWalletProviderFactory.makeProvider()

        provider.request(.oneInchTokens(config: config)).map { response -> [String: Oneinch.ERC20Token] in
            try JSONDecoder().decode([String: Oneinch.ERC20Token].self, from: response.data)
        }.map { data -> [Oneinch.ERC20Token] in
            return data.map { $0.value }
        }.done { response in
            self.availableTokens = self.predefinedTokens + response
        }.cauterize()
    }
}
