// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletOpenSea

final class OpenSea {
    private let storage: Storage<[AddressAndRPCServer: OpenSeaNonFungiblesToAddress]> = .init(fileName: "OpenSea", defaultValue: [:])
    private var cachedPromises: AtomicDictionary<AddressAndRPCServer, Promise<OpenSeaNonFungiblesToAddress>> = .init()
    private let queue: DispatchQueue = DispatchQueue(label: "com.OpenSea.UpdateQueue")
    private lazy var networkProvider: OpenSeaNetworkProvider = OpenSeaNetworkProvider(queue: queue)

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

        return makeFetchPromise(for: key)
    }

    private func makeFetchPromise(for key: AddressAndRPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        if let promise = cachedPromises[key] {
            if promise.isResolved {
                let promise = fetchFromLocalAndRemotePromise(key: key)
                cachedPromises[key] = promise

                return promise
            } else {
                return promise
            }
        } else {
            let promise = fetchFromLocalAndRemotePromise(key: key)
            cachedPromises[key] = promise

            return promise
        }
    }

    private func fetchFromLocalAndRemotePromise(key: AddressAndRPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        return networkProvider
            .fetchAssetsPromise(address: key.address, server: key.server)
            .map(on: queue, { [weak storage] result in
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
            }).ensure(on: queue, {
                self.cachedPromises[key] = .none
            })
    }

    static func fetchAssetImageUrl(for value: Eip155URL, server: RPCServer) -> Promise<URL> {
        OpenSea().networkProvider.fetchAssetImageUrl(for: value, server: server)
    }

    static func collectionStats(slug: String, server: RPCServer) -> Promise<Stats> {
        OpenSea().networkProvider.collectionStats(slug: slug, server: server)
    }
}
