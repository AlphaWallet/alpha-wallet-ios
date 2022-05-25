//
//  TickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.06.2022.
//

import Foundation
import Combine

protocol TickerIdsFetcher {
    func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never>
}

class TickerIdsFetcherImpl: TickerIdsFetcher {
    private let providers: [TickerIdsFetcher]
    private let storage: TickerIdsStorage
    private let spamTokens = SpamTokens()

    init(providers: [TickerIdsFetcher], storage: TickerIdsStorage) {
        self.providers = providers
        self.storage = storage
    }

    /// Returns associated ticker id, callback on .main queue, or immideatelly if ticker id has already exists
    func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        let spamNeedle = AddressAndRPCServer(address: token.contractAddress, server: token.server)
        if spamTokens.isSpamToken(spamNeedle) { return .just(nil) }
        
        let publishers = providers.map { $0.tickerId(for: token) }
        
        func firstMatchingTickerId(_ publishers: [AnyPublisher<TickerIdString?, Never>]) -> AnyPublisher<TickerIdString?, Never> {
            var publishers = publishers

            guard !publishers.isEmpty else { return .just(nil) }
            let publisher = publishers.removeFirst()

            return publisher.flatMap { ticker -> AnyPublisher<TickerIdString?, Never> in
                guard let ticker = ticker else { return firstMatchingTickerId(publishers) }
                return .just(ticker)
            }.eraseToAnyPublisher()
        }

        return firstMatchingTickerId(publishers)
    }
}
