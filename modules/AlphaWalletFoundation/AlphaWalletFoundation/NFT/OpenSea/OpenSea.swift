// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore
import AlphaWalletOpenSea
import AlphaWalletTokenScript
import Combine

public typealias Stats = AlphaWalletOpenSea.NftCollectionStats

public final class OpenSea {
    private let analytics: AnalyticsLogger
    private let storage: Storage<[AddressAndRPCServer: OpenSeaAddressesToNonFungibles]> = .init(fileName: "OpenSea", defaultValue: [:])
    private let queue = DispatchQueue(label: "org.alphawallet.swift.openSea")
    private let config: Config
    private let server: RPCServer
    private let openSea: AlphaWalletOpenSea.OpenSea

    private let excludeContracts: [(AlphaWallet.Address, ChainId)] = [
        (AlphaWalletTokenScript.Constants.uefaMainnet.0, AlphaWalletTokenScript.Constants.uefaMainnet.1.chainID)
    ]

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

    public func nonFungible(wallet: Wallet) -> AnyPublisher<OpenSeaAddressesToNonFungibles, Never> {
        guard !config.development.isOpenSeaFetchingDisabled else { return .empty() }

        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)

        guard OpenSea.isServerSupported(key.server) else {
            return .just([:])
        }

        return openSea.fetchAssetsCollections(owner: wallet.address, chainId: server.chainID, excludeContracts: excludeContracts)
            .map { [weak storage] result -> OpenSeaAddressesToNonFungibles in
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
            }.eraseToAnyPublisher()
    }

    public func fetchAsset(for value: Eip155URL) -> AnyPublisher<NftAsset, PromiseError> {
        //OK and safer to return a promise that never resolves so we don't mangle with real OpenSea data we stored previously, since this is for development only
        guard !config.development.isOpenSeaFetchingDisabled else { return .empty() }

        return openSea.fetchAsset(asset: value.path, chainId: server.chainID)
    }

    public func collectionStats(collectionId: String) -> AnyPublisher<Stats, PromiseError> {
        guard !config.development.isOpenSeaFetchingDisabled else { return .empty() }

        return openSea.collectionStats(collectionId: collectionId, chainId: server.chainID)
    }

    private static func openSeaApiKeys(config: Config) -> [Int: String] {
        guard !config.development.isOpenSeaFetchingDisabled else { return [:] }
        var results: [Int: String] = [:]

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
        switch error {
        case .rateLimited:
            analytics.log(error: Analytics.WebApiErrors.openSeaRateLimited)
        case .expiredApiKey:
            analytics.log(error: Analytics.WebApiErrors.openSeaExpiredApiKey)
        case .invalidApiKey:
            analytics.log(error: Analytics.WebApiErrors.openSeaInvalidApiKey)
        case .invalidJson, .internal:
            break
        }
    }
}

