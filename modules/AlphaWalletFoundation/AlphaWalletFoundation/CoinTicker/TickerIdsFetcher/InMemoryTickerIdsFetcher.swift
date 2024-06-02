//
//  InMemoryTickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.06.2022.
//

import Combine
import Foundation

import AlphaWalletCore

import CombineExt

public class InMemoryTickerIdsFetcher: TickerIdsFetcher {
    private let storage: TickerIdsStorage

    public init(storage: TickerIdsStorage) {
        self.storage = storage
    }

    /// Returns already defined, stored associated with token ticker id
    public func tickerId(for token: TokenMappedToTicker) async -> TickerIdString? {
        if let id = token.knownCoinGeckoTickerId {
            return id
        } else {
            return await self.storage.knownTickerId(for: token)
        }
    }
}
