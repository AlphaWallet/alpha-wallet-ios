// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletCore
import AlphaWalletOpenSea

public typealias Stats = AlphaWalletOpenSea.Stats

public final class OpenSea {
    private let analytics: AnalyticsLogger
    private let storage: Storage<[AddressAndRPCServer: OpenSeaAddressesToNonFungibles]> = .init(fileName: "OpenSea", defaultValue: [:])
    private let queue = DispatchQueue(label: "org.alphawallet.swift.openSea")
    private lazy var networkProvider: OpenSeaNetworkProvider = OpenSeaNetworkProvider(analytics: analytics)
    private var inFlightPromises: [String: Promise<OpenSeaAddressesToNonFungibles>] = [:]
    private var inFlightFetchImageUrlPromises: [String: Promise<URL>] = [:]
    private var inFlightFetchStatsPromises: [String: Promise<Stats>] = [:]

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    public static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server.serverWithEnhancedSupport {
        case .main, .rinkeby:
            return true
        case .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return false
        }
    }

    public func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<OpenSeaAddressesToNonFungibles> {
        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)

        guard OpenSea.isServerSupported(key.server) else {
            return .value([:])
        }

        return fetchFromLocalAndRemotePromise(key: key)
    }

    private func fetchFromLocalAndRemotePromise(key: AddressAndRPCServer) -> Promise<OpenSeaAddressesToNonFungibles> {
        firstly {
            .value(key)
        }.then(on: queue, { [weak self, queue, networkProvider, weak storage] key -> Promise<OpenSeaAddressesToNonFungibles> in
            let promiseKey = "\(key.address)-\(key.server)"
            if let promise = self?.inFlightPromises[promiseKey] {
                return promise
            } else {
                let promise = networkProvider
                    .fetchAssetsPromise(address: key.address, server: key.server)
                    .map(on: queue, { result -> OpenSeaAddressesToNonFungibles in
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
                        self?.inFlightPromises[promiseKey] = .none
                    })

                self?.inFlightPromises[promiseKey] = promise

                return promise
            }
        })
    }

    public func fetchAssetImageUrl(for value: Eip155URL, server: RPCServer) -> Promise<URL> {
        firstly {
            .value(value)
        }.then(on: queue, { [weak self, queue, networkProvider] value -> Promise<URL> in
            let key = "\(value.description)-\(server)"
            if let promise = self?.inFlightFetchImageUrlPromises[key] {
                return promise
            } else {
                let promise = networkProvider
                    .fetchAssetImageUrl(for: value, server: server)
                    .ensure(on: queue, {
                        self?.inFlightFetchImageUrlPromises[key] = .none
                    })

                self?.inFlightFetchImageUrlPromises[key] = promise

                return promise
            }
        })
    }

    public func collectionStats(slug: String, server: RPCServer) -> Promise<Stats> {
        firstly {
            .value(slug)
        }.then(on: queue, { [weak self, queue, networkProvider] slug -> Promise<Stats> in
            let key = "\(slug)-\(server)"
            if let promise = self?.inFlightFetchStatsPromises[key] {
                return promise
            } else {
                let promise = networkProvider
                    .collectionStats(slug: slug, server: server)
                    .ensure(on: queue, {
                        self?.inFlightFetchStatsPromises[key] = .none
                    })

                self?.inFlightFetchStatsPromises[key] = promise

                return promise
            }
        })

    }
}
