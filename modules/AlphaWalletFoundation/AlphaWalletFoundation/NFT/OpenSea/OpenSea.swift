// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletOpenSea
import AlphaWalletTokenScript
import BigInt

public typealias Stats = AlphaWalletOpenSea.NftCollectionStats

public final class OpenSea {
    private let analytics: AnalyticsLogger
    private let storage: Storage<[AddressAndRPCServer: OpenSeaAddressesToNonFungibles]> = .init(fileName: "OpenSea", defaultValue: [:])
    private let config: Config
    private let server: RPCServer
    private let openSea: AlphaWalletOpenSea.OpenSea

    private let excludeContracts: [(AlphaWallet.Address, RPCServer)] = [
        (AlphaWalletTokenScript.Constants.uefaMainnet.0, AlphaWalletTokenScript.Constants.uefaMainnet.1)
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

        return openSea.fetchAssetsCollections(owner: wallet.address, server: server, excludeContracts: excludeContracts)
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

    public func fetchAsset(contract: AlphaWallet.Address, id: BigUInt) async throws -> NftAsset {
        //OK and safer to return a promise that never resolves so we don't mangle with real OpenSea data we stored previously, since this is for development only
        //TODO fix
        struct DisabledError: Error {}
        guard !config.development.isOpenSeaFetchingDisabled else { throw DisabledError() }

        return try await openSea.fetchAsset(contract: contract, id: id, server: server)
    }

    public func collectionStats(collectionId: String) -> AnyPublisher<Stats, PromiseError> {
        guard !config.development.isOpenSeaFetchingDisabled else { return .empty() }

        return openSea.collectionStats(collectionId: collectionId, server: server)
    }

    private static func openSeaApiKeys(config: Config) -> [RPCServer: String] {
        guard !config.development.isOpenSeaFetchingDisabled else { return [:] }
        var results: [RPCServer: String] = [:]

        results[RPCServer.main] = Constants.Credentials.openseaKey
        results[RPCServer.polygon] = Constants.Credentials.openseaKey
        results[RPCServer.arbitrum] = Constants.Credentials.openseaKey
        results[RPCServer.avalanche] = Constants.Credentials.openseaKey
        results[RPCServer.klaytnCypress] = Constants.Credentials.openseaKey
        results[RPCServer.optimistic] = Constants.Credentials.openseaKey

        return results
    }
}

extension OpenSea: OpenSeaDelegate {
    //TODO openSeaError() should be called for logging to analytics
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

