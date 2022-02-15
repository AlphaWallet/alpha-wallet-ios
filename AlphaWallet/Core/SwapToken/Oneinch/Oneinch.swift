//
//  OneinchHolder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation
import PromiseKit
import Moya

class Oneinch: TokenActionsProvider, SwapTokenURLProviderType {

    var action: String {
        return R.string.localizable.aWalletTokenErc20ExchangeOn1inchButtonTitle()
    }
    private var supportedServers: [RPCServer] {
        return [.main, .binance_smart_chain, .polygon, .optimistic, .arbitrum]
    }

    func rpcServer(forToken token: TokenActionsServiceKey) -> RPCServer? {
        if supportedServers.contains(where: { $0 == token.server }) {
            return token.server
        } else {
            return .main
        }
    }

    var analyticsName: String {
        "Oneinch"
    }

    private static let baseURL = "https://1inch.exchange/#"
    private static let referralSlug = "/r/0x98f21584006c79871F176F8D474958a69e04595B"
    //NOTE: for Oneinch exchange service we need to use two addresses, by default it uses Uptrennd token
    private let predefinedTokens: [Oneinch.ERC20Token] = [
        .init(symbol: "ETH", name: "ETH", address: Constants.nativeCryptoAddressInDatabase, decimal: RPCServer.main.decimals)
    ]
    //NOTE: we use dictionary to improve search tokens
    private var availableTokens: [AlphaWallet.Address: Oneinch.ERC20Token] = [:]
    private let queue = DispatchQueue(label: "com.Oneinch.updateQueue")

    func url(token: TokenActionsServiceKey) -> URL? {
        var components = URLComponents()
        components.path = Oneinch.referralSlug + "/" + subpath(inputAddress: token.contractAddress)
        //NOTE: URLComponents doesn't allow path to contain # symbol
        guard let pathWithQueryItems = components.url?.absoluteString else { return nil }

        return URL(string: Oneinch.baseURL + pathWithQueryItems)
    }

    private func subpath(inputAddress: AlphaWallet.Address) -> String {
        return [token(address: inputAddress), token(address: defaultOutputAddress(forInput: inputAddress))].compactMap {
            $0?.symbol
        }.joined(separator: "/")
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        return [
            .init(type: .swap(service: self))
        ]
    }

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        switch token.server {
        case .main, .arbitrum:
            return availableTokens[token.contractAddress] != nil
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .custom, .poa, .callisto, .xDai, .classic, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .palm, .palmTestnet, .arbitrumRinkeby:
            return false
        }
    }

    private func token(address: AlphaWallet.Address) -> Oneinch.ERC20Token? {
        return availableTokens[address]
    }

    func fetchSupportedTokens() {
        let config = Config()
        let provider = AlphaWalletProviderFactory.makeProvider()

        provider.request(.oneInchTokens(config: config), callbackQueue: queue).map(on: queue, { response -> [String: Oneinch.ERC20Token] in
            try JSONDecoder().decode(ApiResponsePayload.self, from: response.data).tokens
        }).map(on: queue, { data -> [Oneinch.ERC20Token] in
            data.map { $0.value }
        }).done(on: queue, { response in
            for token in self.predefinedTokens + response {
                self.availableTokens[token.address] = token
            }
        }).catch(on: queue, { error in
            let service = AlphaWalletService.oneInchTokens(config: config)
            let url = service.baseURL.appendingPathComponent(service.path)
            RemoteLogger.instance.logRpcOrOtherWebError("Oneinch error | \(error)", url: url.absoluteString)
        })
    }

    private func defaultOutputAddress(forInput input: AlphaWallet.Address) -> AlphaWallet.Address {
        if input == Constants.nativeCryptoAddressInDatabase {
            //TODO extract a list of known/popular token contracts we use in the app? Would that be too much dependency?
            return AlphaWallet.Address(string: "0xdAC17F958D2ee523a2206206994597C13D831ec7")!
        } else {
            return Constants.nativeCryptoAddressInDatabase
        }
    }
}
