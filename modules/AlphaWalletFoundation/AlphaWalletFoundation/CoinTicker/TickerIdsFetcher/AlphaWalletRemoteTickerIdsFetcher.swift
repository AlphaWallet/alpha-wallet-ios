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
    private let tickerIdsFetcher: CoinGeckoTickerIdsFetcher
    private let queue = DispatchQueue(label: "org.alphawallet.swift.remoteTickerIdsFetcher")

    public init(provider: TokenEntriesProvider, tickerIdsFetcher: CoinGeckoTickerIdsFetcher) {
        self.provider = provider
        self.tickerIdsFetcher = tickerIdsFetcher
    }

    /// Returns already defined, stored associated with token ticker id
    public func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        return Just(token)
            .receive(on: queue)
            .flatMap { [provider] _ in provider.tokenEntries().replaceError(with: []) }
            .flatMap { [weak self] entries -> AnyPublisher<TickerIdString?, Never> in
                guard let strongSelf = self else { return .empty() }
                return strongSelf.resolveTickerId(in: entries, for: token)
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func resolveTickerId(in tokenEntries: [TokenEntry], for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        return Just(token)
            .map { token -> TokenEntry? in
                let targetContract: Contract = .init(address: token.contractAddress.eip55String, chainId: token.server.chainID)
                return tokenEntries.first(where: { entry in entry.contracts.contains(targetContract) })
            }.flatMap { [weak self] entry -> AnyPublisher<TickerIdString?, Never> in
                guard let strongSelf = self else { return .empty() }
                guard let entry = entry else { return .just(nil) }

                return strongSelf.lookupAnyTickerId(for: entry, token: token)
            }.eraseToAnyPublisher()
    }
    /// Searches for non nil ticker id in token entries array, might be improved for large entries array.
    private func lookupAnyTickerId(for entry: TokenEntry, token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        let publishers = entry.contracts.compactMap { contract -> TokenMappedToTicker? in
            guard let contractAddress = AlphaWallet.Address(string: contract.address) else { return nil }
            let server = RPCServer(chainID: contract.chainId)

            return TokenMappedToTicker(symbol: token.symbol, name: token.name, contractAddress: contractAddress, server: server, coinGeckoId: nil)
        }.map { tickerIdsFetcher.tickerId(for: $0) }

        return Publishers.MergeMany(publishers).collect()
            .map { tickerIds in tickerIds.compactMap { $0 }.first }
            .eraseToAnyPublisher()
    }
}
