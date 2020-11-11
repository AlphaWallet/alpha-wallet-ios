////
////  OneinchTokensStorage.swift
////  AlphaWallet
////
////  Created by Vladyslav Shepitko on 26.11.2020.
////
//
//import UIKit
//import PromiseKit
//import Moya
//
//protocol OneinchTokensStorageType {
//    func isSupport(token: TokenObject) -> Bool
//    func token(address: AlphaWallet.Address) -> Oneinch.ERC20Token?
//    func fetchSupportedTokens()
//}
//
//class OneinchTokensStorage: OneinchTokensStorageType {
//    
//    private let predefinedTokens: [Oneinch.ERC20Token] = [
//        .init(symbol: "ETH", name: "ETH", address: Constants.nativeCryptoAddressInDatabase, decimal: 18)
//    ]
//
//    private(set) var availableTokens: [Oneinch.ERC20Token] = []
//
//    func isSupport(token: TokenObject) -> Bool {
//        switch token.server {
//        case .main:
//            return availableTokens.contains(where: { $0.address == token.contractAddress })
//        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .custom, .poa, .callisto, .xDai, .classic, .binance_smart_chain, .binance_smart_chain_testnet:
//            return false
//        }
//    }
//
//    func token(address: AlphaWallet.Address) -> Oneinch.ERC20Token? {
//        return availableTokens.first(where: { $0.address == address })
//    }
//
//    func fetchSupportedTokens() {
//        let config = Config()
//        let provider = AlphaWalletProviderFactory.makeProvider()
//
//        provider.request(.oneInchTokens(config: config)).map { response -> [String: Oneinch.ERC20Token] in
//            try JSONDecoder().decode([String: Oneinch.ERC20Token].self, from: response.data)
//        }.map { data -> [Oneinch.ERC20Token] in
//            return data.map { $0.value }
//        }.done { response in
//            self.availableTokens = self.predefinedTokens + response
//        }.cauterize()
//    }
//}
//
