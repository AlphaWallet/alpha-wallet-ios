//
//  OpenSeaNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.03.2022.
//

import AlphaWalletOpenSea
import PromiseKit

final class OpenSeaNetworkProvider {
    private let openSea: AlphaWalletOpenSea.OpenSea

    init(queue: DispatchQueue) {
        self.openSea = AlphaWalletOpenSea.OpenSea(apiKeys: Self.openSeaApiKeys(), queue: queue)
    }

    func fetchAssetsPromise(address owner: AlphaWallet.Address, server: RPCServer) -> Promise<Response<OpenSeaNonFungiblesToAddress>> {
        //Ignore UEFA from OpenSea, otherwise the token type would be saved wrongly as `.erc721` instead of `.erc721ForTickets`
        let excludeContracts: [(AlphaWallet.Address, ChainId)] = [(Constants.uefaMainnet, RPCServer.main.chainID)]
        return openSea.fetchAssetsPromise(address: owner, chainId: server.chainID, excludeContracts: excludeContracts)
    }

    func fetchAssetImageUrl(for value: Eip155URL, server: RPCServer) -> Promise<URL> {
        openSea.fetchAssetImageUrl(path: value.path, chainId: server.chainID)
    }

    func collectionStats(slug: String, server: RPCServer) -> Promise<Stats> {
        //TODO this is a little strange. Calling back and forth. Refactor
        openSea.collectionStats(slug: slug, chainId: server.chainID)
    }

    private static func openSeaApiKeys() -> [Int: String] {
        var results = [Int: String]()
        results[RPCServer.main.chainID] = Constants.Credentials.openseaKey
        results[RPCServer.rinkeby.chainID] = nil
        return results
    }
}