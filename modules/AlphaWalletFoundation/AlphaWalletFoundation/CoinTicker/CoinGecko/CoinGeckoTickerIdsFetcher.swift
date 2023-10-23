//
//  SupportedTickerIdsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2022.
//

import Combine
import Foundation
import AlphaWalletCore
import CombineExt

public protocol SupportedTickerIdsFetcherConfig {
    var tickerIdsLastFetchedDate: Date? { get set }
}

/// Ticker ids are havy objects, that don't change often, keep them cached and in separate fetcher to extract logic
public final class SupportedTickerIdsFetcher: TickerIdsFetcher {
    private let networking: CoinTickerNetworking
    private let storage: TickerIdsStorage & CoinTickersStorage
    private var config: SupportedTickerIdsFetcherConfig
    private let pricesCacheLifetime: TimeInterval
    private var fetchSupportedTickerIdsTask: Task<Void, Never>?

    /// Init method
    /// - pricesCacheLifetime - default value 604800, one week
    /// - networkProvider
    /// - storage
    /// - config
    public init(networking: CoinTickerNetworking, storage: TickerIdsStorage & CoinTickersStorage, config: SupportedTickerIdsFetcherConfig, pricesCacheLifetime: TimeInterval = 604800) {
        self.networking = networking
        self.storage = storage
        self.config = config
        self.pricesCacheLifetime = pricesCacheLifetime
    }

    /// Searching for ticker id very havy operation, and takes to mutch time, we use cacing in `knownTickerIds` to store all know ticker ids
    public func tickerId(for token: TokenMappedToTicker) async -> TickerIdString? {
        do {
            try await fetchSupportedTickerIds()
        } catch {
            return nil
        }
        if let tickerId = await storage.tickerId(for: token)?.id {
            storage.addOrUpdate(tickerId: tickerId, for: token)
            return tickerId
        } else {
            return nil
        }
    }

    private func fetchSupportedTickerIds() async throws {
        //TODO pass in Config instance instead
        if Config().development.isAutoFetchingDisabled {
            return
        }
        if let lastFetchingDate = config.tickerIdsLastFetchedDate, Date().timeIntervalSince(lastFetchingDate) <= pricesCacheLifetime, await storage.hasTickerIds() {
           return
        } else {
            if let task = fetchSupportedTickerIdsTask {
                return await task.value
            } else {
                let task: Task<Void, Never> = Task { () -> Void in
                    do {
                        let tickerIds = try await networking.fetchSupportedTickerIds()
                        storage.addOrUpdate(tickerIds: tickerIds)
                        config.tickerIdsLastFetchedDate = Date()
                        self.fetchSupportedTickerIdsTask = nil
                    } catch {}
                }
                fetchSupportedTickerIdsTask = task
                return try await task.value
            }
        }
    }
}

extension Config: SupportedTickerIdsFetcherConfig {
    static let tickerIdsLastFetchedDateKey = "tickerIdsLastFetchedDateKey"

    public var tickerIdsLastFetchedDate: Date? {
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
