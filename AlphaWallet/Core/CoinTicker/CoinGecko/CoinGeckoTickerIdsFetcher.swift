//
//  CoinGeckoTickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2022.
//

import Combine
import Foundation

/// Ticker ids are havy objects, that don't change often, keep them cached and in separate fetcher to extract logic
class CoinGeckoTickerIdsFetcher: TickerIdsFetcher {
    private let networkProvider: CoinGeckoNetworkProviderType
    private let spamTokens = SpamTokens()
    private let storage: TickerIdsStorage & CoinTickersStorage
    private var config: Config
    private let pricesCacheLifetime: TimeInterval = 604800 // one week
    private var fetchSupportedTickerIdsPublisher: AnyPublisher<Void, CoinGeckoNetworkProviderError>?

    init(networkProvider: CoinGeckoNetworkProviderType, storage: TickerIdsStorage & CoinTickersStorage, config: Config) {
        self.networkProvider = networkProvider
        self.storage = storage
        self.config = config
    }

    /// Searching for ticker id very havy operation, and takes to mutch time, we use cacing in `knownTickerIds` to store all know ticker ids
    func tickerId(for token: TokenMappedToTicker) -> AnyPublisher<TickerIdString?, Never> {
        return Just(token)
            .receive(on: Config.backgroundQueue)
            .flatMap { [weak self, storage] token -> AnyPublisher<TickerIdString?, Never> in
                guard let strongSelf = self else { return .empty() }
                return strongSelf.fetchSupportedTickerIds()
                    .map { _ in return TickerIdFilter(tickerIds: storage.tickerIds).tickerId(forToken: token) }
                    .replaceError(with: nil)
                    .eraseToAnyPublisher()
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func fetchSupportedTickerIds() -> AnyPublisher<Void, CoinGeckoNetworkProviderError> {
        if let lastFetchingDate = config.tickerIdsLastFetchedDate, Date().timeIntervalSince(lastFetchingDate) <= pricesCacheLifetime, storage.hasTickerIds() {
            return .just(())
        } else {
            if let publisher = fetchSupportedTickerIdsPublisher {
                return publisher
            } else {
                let publisher = networkProvider.fetchSupportedTickerIds()
                    .handleEvents(receiveOutput: { [storage, weak self] tickerIds in
                        storage.addOrUpdate(tickerIds: tickerIds)
                        self?.config.tickerIdsLastFetchedDate = Date()
                    }, receiveCompletion: { [weak self] _ in
                        self?.fetchSupportedTickerIdsPublisher = .none
                    }).map { _ in }
                    .share()
                    .eraseToAnyPublisher()

                fetchSupportedTickerIdsPublisher = publisher

                return publisher
            }
        }
    }
}

extension Config {
    static let tickerIdsLastFetchedDateKey = "tickerIdsLastFetchedDateKey"

    var tickerIdsLastFetchedDate: Date? {
        get {
            guard let timeinterval = defaults.value(forKey: Config.tickerIdsLastFetchedDateKey) as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: timeinterval)
        }
        set {
            if let value = newValue {
                defaults.set(value.timeIntervalSince1970, forKey: Config.tickerIdsLastFetchedDateKey)
            } else {
                defaults.removeObject(forKey: Config.tickerIdsLastFetchedDateKey)
            }
        }
    }
}
