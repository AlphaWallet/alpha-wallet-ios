// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletCore
import AlphaWalletOpenSea

final class OpenSea {
    private let storage: Storage<[AddressAndRPCServer: OpenSeaNonFungiblesToAddress]> = .init(fileName: "OpenSea", defaultValue: [:])
    private lazy var networkProvider: OpenSeaNetworkProvider = OpenSeaNetworkProvider()

    init() {
        //no-op
    }
    
    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main, .rinkeby:
            return true
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet:
            return false
        }
    }

    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)

        guard OpenSea.isServerSupported(key.server) else {
            return .value([:])
        }

        return fetchFromLocalAndRemotePromise(key: key)
    }

    private func fetchFromLocalAndRemotePromise(key: AddressAndRPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        return networkProvider
            .fetchAssetsPromise(address: key.address, server: key.server)
            .map(on: .none, { [weak storage] result in
                if result.hasError {
                    let merged = (storage?.value[key] ?? [:])
                        .merging(result.result) { Array(Set($0 + $1)) }

                    if merged.isEmpty {
                        //no-op
                    } else {
                        storage?.value[key] = merged
                    }
                } else {
                    storage?.value[key] = result.result
                }

                return storage?.value[key] ?? result.result
            }) 
    }

    static func fetchAssetImageUrl(for value: Eip155URL, server: RPCServer) -> Promise<URL> {
        OpenSeaNetworkProvider().fetchAssetImageUrl(for: value, server: server)
    }

    static func collectionStats(slug: String, server: RPCServer) -> Promise<Stats> {
        OpenSeaNetworkProvider().collectionStats(slug: slug, server: server)
    }
}
