//
//  AlphaWalletRemoteTickerIdsFetcher.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.09.2022.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletCore

/// Looks up for tokens groups, and searches for each token matched in group to resolve ticker id. We know that tokens in group relate to same coin, on different chaing.
/// - Loads tokens groups
/// - Finds appropriate group for token
/// - Resolves ticker id, for each token in group
/// - Returns first matching ticker id
public class AlphaWalletRemoteTickerIdsFetcher: TickerIdsFetcher {
    private let provider: TokenEntriesProvider
    private let tickerIdsFetcher: SupportedTickerIdsFetcher

    public init(provider: TokenEntriesProvider, tickerIdsFetcher: SupportedTickerIdsFetcher) {
        self.provider = provider
        self.tickerIdsFetcher = tickerIdsFetcher
    }

    /// Returns already defined, stored associated with token ticker id
    public func tickerId(for token: TokenMappedToTicker) async -> TickerIdString? {
        let entries: [TokenEntry] = (try? await provider.tokenEntries()) ?? []
        return await resolveTickerId(in: entries, for: token)
    }

    private func resolveTickerId(in tokenEntries: [TokenEntry], for token: TokenMappedToTicker) async -> TickerIdString? {
        let targetContract: TokenEntry.Contract = .init(address: token.contractAddress.eip55String, chainId: token.server.chainID)
        if let entry = tokenEntries.first(where: { entry in entry.contracts.contains(targetContract) }) {
            return await lookupAnyTickerId(for: entry, token: token)
        } else {
            return nil
        }
    }

    /// Searches for non nil ticker id in token entries array, might be improved for large entries array.
    private func lookupAnyTickerId(for entry: TokenEntry, token: TokenMappedToTicker) async -> TickerIdString? {
        let tokensMappedToTickerId: [TokenMappedToTicker] = entry.contracts.compactMap { contract -> TokenMappedToTicker? in
            guard let contractAddress = AlphaWallet.Address(string: contract.address) else { return nil }
            let server = RPCServer(chainID: contract.chainId)
            return TokenMappedToTicker(symbol: token.symbol, name: token.name, contractAddress: contractAddress, server: server, coinGeckoId: nil)
        }
        for each in tokensMappedToTickerId {
            if let tickerId = await tickerIdsFetcher.tickerId(for: each) {
                return tickerId
            }
        }
        return nil
    }
}
