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
    private var inlightPromises: AtomicDictionary<FetchTickerKey, AnyCancellable> = .init()
    /// Resolving ticker ids operations
    private var tickerResolvers: AtomicDictionary<TokenMappedToTicker, AnyCancellable> = .init()

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
        inlightPromises.values.values.forEach { $0.cancel() }
        inlightPromises.removeAll()
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
        //NOTE: cancel all previous requests for prev currency
        inlightPromises.removeAll { $0.currency != currency }

        let targetTokensToFetchTickers = tokens.filter {
            let key = FetchTickerKey(contractAddress: $0.contractAddress, server: $0.server, currency: currency)
            if inlightPromises[key] != nil {
                return false
            } else {
                return force || hasExpiredTickersLifeTimeSinceLastUpdate(for: $0, currency: currency)
            }
        }

        guard !targetTokensToFetchTickers.isEmpty else { return }

        //NOTE: use shared loading tickers operation for batch of tokens
        let operation = fetchBatchOfTickers(for: targetTokensToFetchTickers, currency: currency)
            .sink(receiveCompletion: { [inlightPromises] _ in
                for token in targetTokensToFetchTickers {
                    let key = FetchTickerKey(contractAddress: token.contractAddress, server: token.server, currency: currency)
                    inlightPromises.removeValue(forKey: key)
                }
            }, receiveValue: { [storage] in storage.addOrUpdate(tickers: $0) })

        for token in targetTokensToFetchTickers {
            let key = FetchTickerKey(contractAddress: token.contractAddress, server: token.server, currency: currency)
            inlightPromises[key] = operation
        }
    }

    public func resolveTickerIds(for tokens: [TokenMappedToTicker]) {
        for each in tokens {
            guard tickerResolvers[each] == nil else { continue }

            tickerResolvers[each] = tickerIdsFetcher.tickerId(for: each)
                .handleEvents(receiveCompletion: { [tickerResolvers] _ in
                    tickerResolvers.removeValue(forKey: each)
                }, receiveCancel: { [tickerResolvers] in
                    tickerResolvers.removeValue(forKey: each)
                }).sink { _ in }
        }
    }

    /// Returns cached chart history if its not expired otherwise download a new version of history, if ticker id has found
    public func fetchChartHistories(for token: TokenMappedToTicker, force: Bool, periods: [ChartHistoryPeriod], currency: Currency) -> AnyPublisher<[ChartHistoryPeriod: ChartHistory], Never> {
        let publishers = periods.map { fetchChartHistory(force: force, period: $0, for: token, currency: currency) }

        return Publishers.MergeMany(publishers).collect()
            .map { $0.reorder(by: periods) }
            .map { mapped -> [ChartHistoryPeriod: ChartHistory] in
                var values: [ChartHistoryPeriod: ChartHistory] = [:]
                for each in mapped {
                    values[each.period] = each.history
                }
                return values
            }.eraseToAnyPublisher()
    }

    struct HistoryToPeriod {
        let period: ChartHistoryPeriod
        let history: ChartHistory
    }

    private func fetchChartHistory(force: Bool, period: ChartHistoryPeriod, for token: TokenMappedToTicker, currency: Currency) -> AnyPublisher<HistoryToPeriod, Never> {
        return tickerIdsFetcher.tickerId(for: token)
            .flatMap { [storage, networking, weak self] tickerId -> AnyPublisher<HistoryToPeriod, Never> in
                guard let strongSelf = self else { return .empty() }
                guard let tickerId = tickerId.flatMap({ AssignedCoinTickerId(tickerId: $0, token: token) }) else {
                    return .just(.init(period: period, history: .empty(currency: currency)))
                }

                if let data = storage.chartHistory(period: period, for: tickerId, currency: currency), !strongSelf.hasExpired(history: data, for: period), !force {
                    return .just(.init(period: period, history: data.history))
                } else {
                    return networking.fetchChartHistory(for: period, tickerId: tickerId.tickerId, currency: currency)
                        .handleEvents(receiveOutput: { history in
                            storage.addOrUpdateChartHistory(history: history, period: period, for: tickerId)
                        }).replaceError(with: .empty(currency: currency))
                        .map { HistoryToPeriod(period: period, history: $0) }
                        .receive(on: RunLoop.main)
                        .eraseToAnyPublisher()
                }
            }.eraseToAnyPublisher()
    }

    private func hasExpiredTickersLifeTimeSinceLastUpdate(for token: TokenMappedToTicker, currency: Currency) -> Bool {
        let key = AddressAndRPCServer(address: token.contractAddress, server: token.server)
        if let ticker = storage.ticker(for: key, currency: currency), Date().timeIntervalSince(ticker.lastUpdatedAt) <= pricesCacheLifetime {
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

    private func fetchBatchOfTickers(for tokens: [TokenMappedToTicker], currency: Currency) -> AnyPublisher<[AssignedCoinTickerId: CoinTicker], PromiseError> {
        let publishers = tokens.map { token in
            tickerIdsFetcher.tickerId(for: token).map { $0.flatMap { AssignedCoinTickerId(tickerId: $0, token: token) } }
        }

        return Publishers.MergeMany(publishers).collect()
            .setFailureType(to: PromiseError.self)
            .flatMap { [networking] tickerIds -> AnyPublisher<[AssignedCoinTickerId: CoinTicker], PromiseError> in
                let tickerIds = tickerIds.compactMap { $0 }
                let ids = tickerIds.compactMap { $0.tickerId }

                guard !ids.isEmpty else {
                    return .just([:])
                }

                return networking.fetchTickers(for: ids, currency: currency).map { tickers in
                    var result: [AssignedCoinTickerId: CoinTicker] = [:]

                    for ticker in tickers {
                        for tickerId in tickerIds.filter({ $0.tickerId == ticker.id }) {
                            result[tickerId] = ticker
                        }
                    }
                    return result
                }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
}

extension BaseCoinTickersFetcher.HistoryToPeriod: Reorderable {
    typealias OrderElement = ChartHistoryPeriod
    var orderElement: ChartHistoryPeriod { return period }
}
