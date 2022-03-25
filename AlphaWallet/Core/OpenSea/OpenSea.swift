// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import PromiseKit
import Result
import SwiftyJSON 

typealias OpenSeaNonFungiblesToAddress = [AlphaWallet.Address: [OpenSeaNonFungible]]

final class OpenSea: NFTProvider {
    private let storage: SubscribableFileStorage<[AddressAndRPCServer: OpenSeaNonFungiblesToAddress]>
    private var fetchePromises: [AddressAndRPCServer: Promise<OpenSeaNonFungiblesToAddress>] = [:]
    private let queue: DispatchQueue
    private var networkProvider: OpenSeaNetworkProvider

    init() {
        self.queue = DispatchQueue(label: "com.OpenSea.UpdateQueue")
        self.networkProvider = OpenSeaNetworkProviderX(queue: queue)
        self.storage = .init(fileName: "OpenSea", defaultValue: [:])
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main, .rinkeby:
            return true
        case .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            return false
        }
    }

    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)

        guard OpenSea.isServerSupported(key.server) else {
            fetchePromises[key] = .value([:])
            return fetchePromises[key]!
        }

        return makeFetchPromise(for: key)
    }

    private func makeFetchPromise(for key: AddressAndRPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        if let promise = fetchePromises[key] {
            if promise.isResolved {
                let promise = makeFetchFromLocalAndRemotePromise(key: key)
                fetchePromises[key] = promise

                return promise
            } else {
                return promise
            }
        } else {
            let promise = makeFetchFromLocalAndRemotePromise(key: key)
            fetchePromises[key] = promise

            return promise
        }
    }

    private func makeFetchFromLocalAndRemotePromise(key: AddressAndRPCServer) -> Promise<OpenSeaNonFungiblesToAddress> {
        return networkProvider
            .fetchAssetsPromise(address: key.address, server: key.server)
            .map { result in
                if result.hasError {
                    let merged = (self.storage.value[key] ?? [:])
                        .merging(result.result) { Array(Set($0 + $1)) }

                    if merged.isEmpty {
                        //no-op
                    } else {
                        self.storage.value[key] = merged
                    }
                } else {
                    self.storage.value[key] = result.result
                }

                let result = self.storage.value[key] ?? result.result

                let ss = result.map { "\($0.truncateMiddle.suffix(4)) - \($1.count)" }.joined(separator: ",")
                print("XXX.OpenSea local: \(key.server), account: \(key.address.truncateMiddle.suffix(4)), values: [\(ss)]")

                return result
            }
    }

    static func fetchAssetImageUrl(for value: Eip155URL) -> Promise<URL> {
        OpenSea().networkProvider.fetchAssetImageUrl(for: value)
    }

    static func collectionStats(slug: String) -> Promise<Stats> {
        OpenSea().networkProvider.collectionStats(slug: slug)
    }
}
