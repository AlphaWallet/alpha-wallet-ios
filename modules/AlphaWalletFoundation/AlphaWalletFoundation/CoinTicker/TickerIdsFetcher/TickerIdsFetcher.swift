//
//  TickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.06.2022.
//

import Foundation
import Combine

public protocol TickerIdsFetcher: AnyObject {
    func tickerId(for token: TokenMappedToTicker) async -> TickerIdString?
}

/// Returns first matching ticker id, perform searching in data source sequentially, wait until publisher being resolved and resolves next one
public class TickerIdsFetcherImpl: TickerIdsFetcher {
    private let providers: [TickerIdsFetcher]
    private let spamTokens = SpamTokens()

    public init(providers: [TickerIdsFetcher]) {
        self.providers = providers
    }

    /// Returns associated ticker id, callback on .main queue, or immediately if ticker id has already exists
    public func tickerId(for token: TokenMappedToTicker) async -> TickerIdString? {
        let spamNeedle = AddressAndRPCServer(address: token.contractAddress, server: token.server)
        if spamTokens.isSpamToken(spamNeedle) { return nil }
        for each in providers {
            if let tickerId = await each.tickerId(for: token) {
                return tickerId
            }
        }
        return nil
    }
}
