//
//  Ramp.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import UIKit

struct Ramp: TokenActionsProvider, BuyTokenURLProviderType {

    var action: String {
        return R.string.localizable.aWalletTokenBuyTitle()
    }

    var account: Wallet
    private let queue: DispatchQueue = .global()

    func url(token: TokenActionsServiceKey) -> URL? {
        switch token.server {
        case .xDai:
            return URL(string: "\(Constants.buyXDaiWitRampUrl)&userAddress=\(account.address.eip55String)")
        //TODO need to check if Ramp supports these? Or is it taken care of elsehwere
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
            return asset(for: token).flatMap {
                return URL(string: "\(Constants.buyWitRampUrl(asset: $0.symbol))&userAddress=\(account.address.eip55String)")
            }
        }
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        return [
            .init(type: .buy(service: self))
        ]
    }

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        switch token.server {
        case .xDai:
            return true
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
            return asset(for: token) != nil
        }
    }

    private func asset(for token: TokenActionsServiceKey) -> Asset? {
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

        provider.request(.rampAssets(config: config), callbackQueue: queue).map(on: queue, { response -> RampAssetsResponse in
            try JSONDecoder().decode(RampAssetsResponse.self, from: response.data)
        }).map(on: queue, { data -> [Asset] in
            return data.assets
        }).done(on: queue, { response in
            Self.assets = response
        }).catch(on: queue, { error in
            let service = AlphaWalletService.rampAssets(config: config)
            let url = service.baseURL.appendingPathComponent(service.path)
            RemoteLogger.instance.logRpcOrOtherWebError("Ramp error | \(error)", url: url.absoluteString)
        })
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
