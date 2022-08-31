//
//  TickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.06.2022.
//

import Foundation
import Combine

public protocol TickerIdsFetcher: AnyObject {
    func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never>
}
/// Returns first matching ticker id, perform searching in data source sequentially, wait until publisher being resolved and resolves next one
public class TickerIdsFetcherImpl: TickerIdsFetcher {
    private let providers: [TickerIdsFetcher]
    private let spamTokens = SpamTokens()

    public init(providers: [TickerIdsFetcher]) {
        self.providers = providers
    }

    /// Returns associated ticker id, callback on .main queue, or immideatelly if ticker id has already exists
    public func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        let spamNeedle = AddressAndRPCServer(address: token.contractAddress, server: token.server)
        if spamTokens.isSpamToken(spamNeedle) { return .empty() }
        
        let publishers = providers.map { $0.tickerId(for: token) }

        func firstMatchingTickerId(_ publishers: [AnyPublisher<TickerIdString?, Never>]) -> AnyPublisher<TickerIdString?, Never> {
            var publishers = publishers

            guard !publishers.isEmpty else { return .empty() }
            let publisher = publishers.removeFirst()

            return publisher.replaceEmpty(with: nil)
                .flatMap { tickerId -> AnyPublisher<TickerIdString?, Never> in
                    guard let tickerId = tickerId else { return firstMatchingTickerId(publishers) }
                    return .just(tickerId)
                }
            .eraseToAnyPublisher()
        }

        return firstMatchingTickerId(publishers)
    }
}
