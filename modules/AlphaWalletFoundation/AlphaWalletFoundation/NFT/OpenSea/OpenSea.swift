// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletCore
import AlphaWalletOpenSea

public typealias Stats = AlphaWalletOpenSea.NftCollectionStats

public final class OpenSea {
    private let analytics: AnalyticsLogger
    private let storage: Storage<[AddressAndRPCServer: OpenSeaAddressesToNonFungibles]> = .init(fileName: "OpenSea", defaultValue: [:])
    private let queue = DispatchQueue(label: "org.alphawallet.swift.openSea")
    private let openSea: AlphaWalletOpenSea.OpenSea
    private var inFlightPromises: [String: Promise<OpenSeaAddressesToNonFungibles>] = [:]
    private var inFlightFetchImageUrlPromises: [String: Promise<URL>] = [:]
    private var inFlightFetchStatsPromises: [String: Promise<Stats>] = [:]
    private let server: RPCServer
    private let config: Config

    public init(analytics: AnalyticsLogger, server: RPCServer, config: Config) {
        self.config = config
        self.analytics = analytics
        self.server = server
        self.openSea = AlphaWalletOpenSea.OpenSea(apiKeys: Self.openSeaApiKeys(config: config))
        openSea.delegate = self
    }

    public static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main, .polygon, .arbitrum, .avalanche, .klaytnCypress, .optimistic:
            return true
        default:
            return false
        }
    }

    public func nonFungible(wallet: Wallet) -> Promise<OpenSeaAddressesToNonFungibles> {
        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)
        
        guard OpenSea.isServerSupported(key.server) else {
            return .value([:])
        }

        return fetchFromLocalAndRemotePromise(key: key)
    }

    private func fetchFromLocalAndRemotePromise(key: AddressAndRPCServer) -> Promise<OpenSeaAddressesToNonFungibles> {
        //OK and safer to return a promise that never resolves so we don't mangle with real OpenSea data we stored previously, since this is for development only
        guard !config.development.isOpenSeaFetchingDisabled else { return Promise { _ in } }
        //Ignore UEFA from OpenSea, otherwise the token type would be saved wrongly as `.erc721` instead of `.erc721ForTickets`
        let excludeContracts: [(AlphaWallet.Address, ChainId)] = [(Constants.uefaMainnet.0, Constants.uefaMainnet.1.chainID)]

        return firstly {
            .value(key)
        }.then(on: queue, { [weak self, queue, openSea, weak storage] key -> Promise<OpenSeaAddressesToNonFungibles> in
            let promiseKey = "\(key.address)-\(key.server)"
            if let promise = self?.inFlightPromises[promiseKey] {
                return promise
            } else {
                let promise = openSea
                    .fetchAssetsPromise(address: key.address, chainId: key.server.chainID, excludeContracts: excludeContracts)
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

    public func fetchAssetImageUrl(for value: Eip155URL) -> Promise<URL> {
        guard !config.development.isOpenSeaFetchingDisabled else { return Promise { _ in } }

        return firstly {
            .value(value)
        }.then(on: queue, { [weak self, queue, openSea, server] value -> Promise<URL> in
            let key = "\(value.description)-\(server)"
            if let promise = self?.inFlightFetchImageUrlPromises[key] {
                return promise
            } else {
                let promise = openSea
                    .fetchAssetImageUrl(asset: value.path, chainId: server.chainID)
                    .ensure(on: queue, {
                        self?.inFlightFetchImageUrlPromises[key] = .none
                    })

                self?.inFlightFetchImageUrlPromises[key] = promise

                return promise
            }
        })
    }

    public func collectionStats(collectionId: String) -> Promise<Stats> {
        firstly {
            .value(collectionId)
        }.then(on: queue, { [weak self, queue, openSea, server] collectionId -> Promise<Stats> in
            let key = "\(collectionId)-\(server)"
            if let promise = self?.inFlightFetchStatsPromises[key] {
                return promise
            } else {
                let promise = openSea
                    .collectionStats(slug: collectionId, chainId: server.chainID)
                    .ensure(on: queue, {
                        self?.inFlightFetchStatsPromises[key] = .none
                    })

                self?.inFlightFetchStatsPromises[key] = promise

                return promise
            }
        })

    }

    private static func openSeaApiKeys(config: Config) -> [Int: String] {
        //TODO should pass in instead
        guard !config.development.isOpenSeaFetchingDisabled else { return .init() }
        var results = [Int: String]()
        results[RPCServer.main.chainID] = Constants.Credentials.openseaKey
        results[RPCServer.polygon.chainID] = Constants.Credentials.openseaKey
        results[RPCServer.arbitrum.chainID] = Constants.Credentials.openseaKey
        results[RPCServer.avalanche.chainID] = Constants.Credentials.openseaKey
        results[RPCServer.klaytnCypress.chainID] = Constants.Credentials.openseaKey
        results[RPCServer.optimistic.chainID] = Constants.Credentials.openseaKey

        return results
    }
}

extension OpenSea: OpenSeaDelegate {
    public func openSeaError(error: OpenSeaApiError) {
        let e: Analytics.WebApiErrors
        switch error {
        case .rateLimited:
            e = .openSeaRateLimited
        case .expiredApiKey:
            e = .openSeaExpiredApiKey
        case .invalidApiKey:
            e = .openSeaInvalidApiKey
        }
        analytics.log(error: e)
    }
}

