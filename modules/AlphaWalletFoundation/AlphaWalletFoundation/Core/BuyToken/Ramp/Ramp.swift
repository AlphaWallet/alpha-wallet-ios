//
//  Ramp.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import Foundation
import Combine

public final class Ramp: SupportedTokenActionsProvider, BuyTokenURLProviderType {
    private var objectWillChangeSubject = PassthroughSubject<Void, Never>()
    private var assets: AtomicArray<Asset> = .init()
    private let queue: DispatchQueue = .global()

    public var objectWillChange: AnyPublisher<Void, Never> {
        objectWillChangeSubject.eraseToAnyPublisher()
    }
    public let analyticsNavigation: Analytics.Navigation = .onRamp
    public let analyticsName: String = "Ramp"

    public let action: String

    public func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        switch token.server {
        case .xDai:
            return URL(string: "\(Constants.buyXDaiWitRampUrl)&userAddress=\(wallet.address.eip55String)")
        //TODO need to check if Ramp supports these? Or is it taken care of elsehwere
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
            return asset(for: token).flatMap {
                return URL(string: "\(Constants.buyWitRampUrl(asset: $0.symbol))&userAddress=\(wallet.address.eip55String)")
            }
        }
    }

    public init(action: String) {
        self.action = action
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .buy(service: self))]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        switch token.server {
        case .xDai:
            return true
        case .main, .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .custom, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
            return asset(for: token) != nil
        }
    }

    private func asset(for token: TokenActionsIdentifiable) -> Asset? {
        //We only operate for mainnets. This is because we store native cryptos for Ethereum testnets like `.goerli` with symbol "ETH" which would match Ramp's Ethereum token
        guard !token.server.isTestnet else { return nil }
        return assets.first(where: {
            $0.symbol.lowercased() == token.symbol.trimmingCharacters(in: .controlCharacters).lowercased()
                    && $0.decimals == token.decimals
                    && ($0.address == nil ? token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) : $0.address!.sameContract(as: token.contractAddress))
        })
    }

    public func start() {
        queue.async {
            self.fetchSupportedTokens()
        }
    } 

    private func fetchSupportedTokens() {
        let provider = AlphaWalletProviderFactory.makeProvider()

        provider.request(.rampAssets, callbackQueue: queue)
            .map(on: queue, { response -> [Asset] in
                try JSONDecoder().decode(RampAssetsResponse.self, from: response.data).assets
            }).done(on: queue, { response in
                self.assets.set(array: response)
                self.objectWillChangeSubject.send(())
            }).catch(on: queue, { error in
                let service = AlphaWalletService.rampAssets
                let url = service.baseURL.appendingPathComponent(service.path)
                RemoteLogger.instance.logRpcOrOtherWebError("Ramp error | \(error)", url: url.absoluteString)
            })
    }
}

private struct RampAssetsResponse {
    let assets: [Asset]
}

private struct Asset {
    let symbol: String
    let address: AlphaWallet.Address?
    let name: String
    let decimals: Int
}

extension RampAssetsResponse: Codable {}

extension Asset: Codable {
    private enum CodingKeys: String, CodingKey {
        case symbol
        case address
        case name
        case decimals
    }

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
