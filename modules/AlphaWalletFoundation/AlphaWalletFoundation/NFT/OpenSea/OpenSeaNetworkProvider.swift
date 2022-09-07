//
//  OpenSeaNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.03.2022.
//

import AlphaWalletOpenSea
import PromiseKit

final class OpenSeaNetworkProvider {
    private let analytics: AnalyticsLogger
    private let openSea: AlphaWalletOpenSea.OpenSea
    //TODO should pass in instead
    private let config: Config = Config()

    init(analytics: AnalyticsLogger, queue: DispatchQueue) {
        self.analytics = analytics
        self.openSea = AlphaWalletOpenSea.OpenSea(apiKeys: Self.openSeaApiKeys(), queue: queue)
        openSea.delegate = self
    }

    func fetchAssetsPromise(address owner: AlphaWallet.Address, server: RPCServer) -> Promise<Response<OpenSeaAddressesToNonFungibles>> {
        //OK and safer to return a promise that never resolves so we don't mangle with real OpenSea data we stored previously, since this is for development only
        guard !config.development.isOpenSeaFetchingDisabled else { return Promise { _ in } }
        //Ignore UEFA from OpenSea, otherwise the token type would be saved wrongly as `.erc721` instead of `.erc721ForTickets`
        let excludeContracts: [(AlphaWallet.Address, ChainId)] = [(Constants.uefaMainnet, RPCServer.main.chainID)]
        return openSea.fetchAssetsPromise(address: owner, chainId: server.chainID, excludeContracts: excludeContracts)
    }

    func fetchAssetImageUrl(for value: Eip155URL, server: RPCServer) -> Promise<URL> {
        //OK and safer to return a promise that never resolves so we don't mangle with real OpenSea data we stored previously, since this is for development only
        guard !config.development.isOpenSeaFetchingDisabled else { return Promise { _ in } }
        return openSea.fetchAssetImageUrl(path: value.path, chainId: server.chainID)
    }

    func collectionStats(slug: String, server: RPCServer) -> Promise<Stats> {
        //OK and safer to return a promise that never resolves so we don't mangle with real OpenSea data we stored previously, since this is for development only
        guard !config.development.isOpenSeaFetchingDisabled else { return Promise { _ in } }
        //TODO this is a little strange. Calling back and forth. Refactor
        return openSea.collectionStats(slug: slug, chainId: server.chainID)
    }

    private static func openSeaApiKeys() -> [Int: String] {
        //TODO should pass in instead
        guard !Config().development.isOpenSeaFetchingDisabled else { return .init() }
        var results = [Int: String]()
        results[RPCServer.main.chainID] = Constants.Credentials.openseaKey
        results[RPCServer.rinkeby.chainID] = nil
        return results
    }
}

extension OpenSeaNetworkProvider: OpenSeaDelegate {
    func openSeaError(error: OpenSeaApiError) {
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
