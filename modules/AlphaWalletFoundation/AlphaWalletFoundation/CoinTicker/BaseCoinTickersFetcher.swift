//
//  BaseCoinTickersFetcher.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 16.09.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public class BaseCoinTickersFetcher: CoinTickersFetcher {
    private let pricesCacheLifetime: TimeInterval = 60 * 60
    private let dayChartHistoryCacheLifetime: TimeInterval = 60 * 60
    private let storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage
    private let networking: CoinTickerNetworking
    private let tickerIdsFetcher: TickerIdsFetcher
    /// Cached fetch ticker prices operations
    private var inflightFetchers: AtomicDictionary<FetchTickerKey, Task<Void, Never>> = .init()
    /// Resolving ticker ids operations
    private var inflightResolvers: AtomicDictionary<TokenMappedToTicker, Task<Void, Never>> = .init()

    public init(networking: CoinTickerNetworking, storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage, tickerIdsFetcher: TickerIdsFetcher) {
        self.networking = networking
        self.tickerIdsFetcher = tickerIdsFetcher
        self.storage = storage

        //NOTE: Remove old files with tickers, ids and price histories
        ["tickers", "tickersIds", "history"].map {
            FileStorage().fileURL(with: $0, fileExtension: "json")
        }.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    public func cancel() {
        inflightFetchers.values.values.forEach { $0.cancel() }
        inflightFetchers.removeAll()
    }

    private struct FetchTickerKey: Hashable {
        let contractAddress: AlphaWallet.Address
        let server: RPCServer
        let currency: Currency
    }

    public func addOrUpdateTestsOnly(ticker: CoinTicker?, for token: TokenMappedToTicker) {
        let tickers: [AssignedCoinTickerId: CoinTicker] = ticker.flatMap { ticker in
            let tickerId = AssignedCoinTickerId(tickerId: "tickerId-\(token.contractAddress)-\(token.server.chainID)", token: token)
            return [tickerId: ticker]
        } ?? [:]

        storage.addOrUpdate(tickers: tickers)
    }

    public func fetchTickers(for tokens: [TokenMappedToTicker], force: Bool = false, currency: Currency) {
        //TODO pass in Config instance instead
        if Config().development.isAutoFetchingDisabled {
            return
        }
        //NOTE: cancel all previous requests for prev currency
        inflightFetchers.removeAll { $0.currency != currency }

        Task { @MainActor in
            var targetTokensToFetchTickers: [TokenMappedToTicker] = []
            for each in tokens {
                let key = FetchTickerKey(contractAddress: each.contractAddress, server: each.server, currency: currency)
                if inflightFetchers[key] != nil {
                    return
                } else {
                    let include = await hasExpiredTickersLifeTimeSinceLastUpdate(for: each, currency: currency)
                    if force || include {
                        targetTokensToFetchTickers.append(each)
                    }
                }
            }

            guard !targetTokensToFetchTickers.isEmpty else { return }

            //NOTE: use shared loading tickers operation for batch of tokens
            let task = Task<Void, Never> {
                do {
                    let tickers = try await fetchBatchOfTickers(for: targetTokensToFetchTickers, currency: currency)
                    storage.addOrUpdate(tickers: tickers)
                } catch {}
                for token in targetTokensToFetchTickers {
                    let key = FetchTickerKey(contractAddress: token.contractAddress, server: token.server, currency: currency)
                    inflightFetchers[key] = nil
                }
            }

            for token in targetTokensToFetchTickers {
                let key = FetchTickerKey(contractAddress: token.contractAddress, server: token.server, currency: currency)
                inflightFetchers[key] = task
            }
        }
    }

    public func resolveTickerIds(for tokens: [TokenMappedToTicker]) {
        for each in tokens {
            guard inflightResolvers[each] == nil else { continue }
            let task = Task<Void, Never> { @MainActor in
                await tickerIdsFetcher.tickerId(for: each)
                inflightResolvers[each] = nil
            }
            inflightResolvers[each] = task
        }
    }

    /// Returns cached chart history if its not expired otherwise download a new version of history, if ticker id has found
    public func fetchChartHistories(for token: TokenMappedToTicker, force: Bool, periods: [ChartHistoryPeriod], currency: Currency) async -> [ChartHistoryPeriod: ChartHistory] {
        //TODO pass in an instance instead
        if Config().development.isAutoFetchingDisabled {
            return [:]
        }
        let unorderedHistoryToPeriods = await periods.asyncMap { await fetchChartHistory(force: force, period: $0, for: token, currency: currency) }
        let historyToPeriods = unorderedHistoryToPeriods.reorder(by: periods)
        var values: [ChartHistoryPeriod: ChartHistory] = [:]
        for each in historyToPeriods {
            values[each.period] = each.history
        }
        return values
    }

    struct HistoryToPeriod {
        let period: ChartHistoryPeriod
        let history: ChartHistory
    }

    private func fetchChartHistory(force: Bool, period: ChartHistoryPeriod, for token: TokenMappedToTicker, currency: Currency) async -> HistoryToPeriod {
        guard let tickerIdString = await tickerIdsFetcher.tickerId(for: token) else { return HistoryToPeriod(period: period, history: ChartHistory.empty(currency: currency)) }
        let tickerId = AssignedCoinTickerId(tickerId: tickerIdString, token: token)

        if let data = await storage.chartHistory(period: period, for: tickerId, currency: currency), !hasExpired(history: data, for: period), !force {
            return HistoryToPeriod(period: period, history: data.history)
        } else {
            do {
                let history = try await networking.fetchChartHistory(for: period, tickerId: tickerId.tickerId, currency: currency)
                storage.addOrUpdateChartHistory(history: history, period: period, for: tickerId)
                return HistoryToPeriod(period: period, history: history)
            } catch {
                return HistoryToPeriod(period: period, history: ChartHistory.empty(currency: currency))
            }
        }
    }

    private func hasExpiredTickersLifeTimeSinceLastUpdate(for token: TokenMappedToTicker, currency: Currency) async -> Bool {
        let key = AddressAndRPCServer(address: token.contractAddress, server: token.server)
        if let ticker = await storage.ticker(for: key, currency: currency), Date().timeIntervalSince(ticker.lastUpdatedAt) <= pricesCacheLifetime {
            return false
        }

        return true
    }

    private func hasExpired(history mappedChartHistory: MappedChartHistory, for period: ChartHistoryPeriod) -> Bool {
        guard ReachabilityManager().isReachable else { return false }

        let hasCacheExpired: Bool
        switch period {
        case .day:
            let fetchDate = mappedChartHistory.fetchDate
            hasCacheExpired = Date().timeIntervalSince(fetchDate) > dayChartHistoryCacheLifetime
        case .week, .month, .threeMonth, .year:
            hasCacheExpired = false
        }
        if hasCacheExpired || mappedChartHistory.history.prices.isEmpty {
            //TODO improve by returning the cached value and returning again after refetching. Harder to do with current implement because promises only resolves once. Maybe the Promise's type should be a subscribable?
            return true
        } else {
            return false
        }
    }

    private func fetchBatchOfTickers(for tokens: [TokenMappedToTicker], currency: Currency) async throws -> [AssignedCoinTickerId: CoinTicker] {
        let assignedCoinTickerIds: [AssignedCoinTickerId] = await tokens.asyncCompactMap { token in
            if let tickerId = await tickerIdsFetcher.tickerId(for: token) {
                return AssignedCoinTickerId(tickerId: tickerId, token: token)
            } else {
                return nil
            }
        }
        let tickerIds = assignedCoinTickerIds.map { $0.tickerId }
        guard !tickerIds.isEmpty else { return [:] }
        let tickers = try await networking.fetchTickers(for: tickerIds, currency: currency)
        var result: [AssignedCoinTickerId: CoinTicker] = [:]
        for ticker in tickers {
            for each in assignedCoinTickerIds.filter({ $0.tickerId == ticker.id }) {
                result[each] = ticker
            }
        }
        return result
    }
}

extension BaseCoinTickersFetcher.HistoryToPeriod: Reorderable {
    typealias OrderElement = ChartHistoryPeriod
    var orderElement: ChartHistoryPeriod { return period }
}
