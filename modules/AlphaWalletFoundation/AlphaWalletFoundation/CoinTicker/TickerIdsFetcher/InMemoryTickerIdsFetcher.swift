//
//  InMemoryTickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.06.2022.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletCore

public class InMemoryTickerIdsFetcher: TickerIdsFetcher {
    private let storage: TickerIdsStorage

    public init(storage: TickerIdsStorage) {
        self.storage = storage
    }

    /// Returns already defined, stored associated with token ticker id
    public func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        if let id = token.knownCoinGeckoTickerId {
            return .just(id)
        } else {
            let tickerId = storage.knownTickerId(for: token)
            return .just(tickerId)
        }
    }
}
