//
//  Ramp.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import UIKit

struct Ramp: TokenActionsProvider, BuyTokenURLProviderType {

    var action: String {
        return "Buy"
    }

    var account: Wallet

    func url(token: TokenObject) -> URL? {
        switch token.server {
        case .xDai:
            return URL(string: "\(Constants.buyXDaiWitRampUrl)&userAddress=\(account.address.eip55String)")
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .taiChi:
            if let asset = asset(for: token) {
                let base = Constants.buyWitRampUrl(asset: asset.symbol)
                return URL(string: "\(base)&userAddress=\(account.address.eip55String)")
            }
        }
        return nil
    }

    func actions(token: TokenObject) -> [TokenInstanceAction] {
        return [
            .init(type: .buy(service: self))
        ]
    }

    func isSupport(token: TokenObject) -> Bool {
        switch token.server {
        case .xDai:
            return true
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .taiChi:
            return asset(for: token) != nil
        }
    }

    private func asset(for token: TokenObject) -> Asset? {
        //We only operate for mainnets. This is because we store native cryptos for Ethereum testnets like `.goerli` with symbol "ETH" which would match Ramp's Ethereum token
        guard !token.server.isTestnet else { return nil }
        return Self.assets.first(where: {
            $0.symbol.lowercased() == token.symbol.trimmingCharacters(in: .controlCharacters).lowercased()
                    && $0.decimals == token.decimals
                    && ($0.address == nil ? token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) : $0.address!.sameContract(as: token.contractAddress))
        })
    }

    private static var assets: [Asset] = []

    func fetchSupportedTokens() {
        let config = Config()
        let provider = AlphaWalletProviderFactory.makeProvider()

        provider.request(.rampAssets(config: config)).map { response -> RampAssetsResponse in
            try JSONDecoder().decode(RampAssetsResponse.self, from: response.data)
        }.map { data -> [Asset] in
            return data.assets
        }.done { response in
            Self.assets = response
        }.cauterize()
    }
}

private struct RampAssetsResponse: Codable {
    let assets: [Asset]
}

private struct Asset: Codable {

    private enum CodingKeys: String, CodingKey {
        case symbol
        case address
        case name
        case decimals
    }

    let symbol: String
    let address: AlphaWallet.Address?
    let name: String
    let decimals: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(String.self, forKey: .address) {
            address = AlphaWallet.Address(string: value)
        } else {
            address = .none
        }

        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        decimals = try container.decode(Int.self, forKey: .decimals)
    }
}
