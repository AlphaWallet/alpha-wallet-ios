//
//  InMemoryTickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.06.2022.
//

import Foundation
import Combine
import CombineExt

/// Provides tokens groups
protocol TokenEntriesProvider {
    func tokenEntries() -> AnyPublisher<[TokenEntry], DataRequestError>
}

/// Looks up for tokens groups, and searches for each token matched in group to resolve ticker id. We know that tokens in group relate to same coin, on different chaing.
/// - Loads tokens groups
/// - Finds appropriate group for token
/// - Resolves ticker id, for each token in group
/// - Returns first matching ticker id
class AlphaWalletRemoteTickerIdsFetcher: TickerIdsFetcher {
    private let provider: TokenEntriesProvider
    private let tickerIdsFetcher: CoinGeckoTickerIdsFetcher

    private lazy var tokenEntries: AnyPublisher<[TokenEntry], Never> = {
        return provider.tokenEntries()
            .replaceError(with: [])
            .share(replay: 1) //TODO: not sure if it will work in case when we send a network call, it might share an error than
            .eraseToAnyPublisher()
    }()

    init(provider: TokenEntriesProvider, tickerIdsFetcher: CoinGeckoTickerIdsFetcher) {
        self.provider = provider
        self.tickerIdsFetcher = tickerIdsFetcher
    }

    /// Returns already defined, stored associated with token ticker id
    func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        return Just(token)
            .receive(on: DispatchQueue.global())
            .flatMap { [unowned self] _ in tokenEntries }
            .flatMap { [unowned self] in self.resolveTickerId(in: $0, for: token) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func resolveTickerId(in tokenEntries: [TokenEntry], for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        return Just(token)
            .map { token -> TokenEntry? in
                let targetContract: Contract = .init(address: token.contractAddress.eip55String, chainId: token.server.chainID)
                return tokenEntries.first(where: { entry in entry.contracts.contains(targetContract) })
            }.flatMap { [unowned self] entry -> AnyPublisher<TickerIdString?, Never> in
                guard let entry = entry else { return .just(nil) }

                return self.lookupAnyTickerId(for: entry, token: token)
            }.eraseToAnyPublisher()
    }

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

class InMemoryTickerIdsFetcher: TickerIdsFetcher {
    private let storage: TickerIdsStorage

    init(storage: TickerIdsStorage) {
        self.storage = storage
    }

    /// Returns already defined, stored associated with token ticker id
    func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        if let id = token.knownCoinGeckoTickerId {
            return .just(id)
        } else {
            let tickerId = storage.knownTickerId(for: token)
            return .just(tickerId)
        }
    }
}

//TODO: Future impl for remote TokenEntries provider
final class RemoteTokenEntriesProvider: TokenEntriesProvider {
    func tokenEntries() -> AnyPublisher<[TokenEntry], DataRequestError> {
        return .just([])
            .share()
            .eraseToAnyPublisher()
    }
}

final class FileTokenEntriesProvider: TokenEntriesProvider {
    private let fileName: String

    init(fileName: String) {
        self.fileName = fileName
    }

    func tokenEntries() -> AnyPublisher<[TokenEntry], DataRequestError> {
        do {
            guard let bundlePath = Bundle.main.path(forResource: fileName, ofType: "json") else { throw TokenJsonReader.error.fileDoesNotExist }
            guard let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8) else { throw TokenJsonReader.error.fileIsNotUtf8 }
            do {
                let decodedTokenEntries = try JSONDecoder().decode([TokenEntry].self, from: jsonData)
                return .just(decodedTokenEntries)
            } catch DecodingError.dataCorrupted {
                throw TokenJsonReader.error.fileCannotBeDecoded
            } catch {
                throw TokenJsonReader.error.unknown(error)
            }
        } catch {
            return .fail(.general(error: error))
        }
    }
}
