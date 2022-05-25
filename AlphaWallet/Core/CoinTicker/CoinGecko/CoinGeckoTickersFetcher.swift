//
//  CoinGeckoTickersFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2022.
//

import Combine
import Foundation

final class CoinGeckoTickersFetcher: CoinTickersFetcherType {
    private let pricesCacheLifetime: TimeInterval = 60 * 60
    private let dayChartHistoryCacheLifetime: TimeInterval = 60 * 60
    private let config: Config
    private let storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage
    private let networkProvider: CoinGeckoNetworkProvider
    private let tickerIdsFetcher: TickerIdsFetcherImpl
    /// Cached fetch ticker prices operations
    private var promises: AtomicDictionary<TokenMappedToTicker, AnyCancellable> = .init()
    /// Ticker last update dates
    private var tickerUpdatesDates: AtomicDictionary<TokenMappedToTicker, Date> = .init()
    /// Resolving ticker ids operations
    private var tickerResolvers: AtomicDictionary<TokenMappedToTicker, AnyCancellable> = .init()

    var tickersDidUpdate: AnyPublisher<Void, Never> {
        return storage.tickersDidUpdate
    }

    var updateTickerId: AnyPublisher<(tickerId: TickerIdString, key: AddressAndRPCServer), Never> {
        storage.updateTickerId
    }

    init(networkProvider: CoinGeckoNetworkProvider, config: Config, storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage) {
        self.networkProvider = networkProvider
        let coinGeckoTickerIdsFetcher = CoinGeckoTickerIdsFetcher(networkProvider: networkProvider, storage: storage, config: config)
        let fileTokenEntriesProvider = FileTokenEntriesProvider(fileName: "tokens_2")

        self.tickerIdsFetcher = TickerIdsFetcherImpl(providers: [
            InMemoryTickerIdsFetcher(storage: storage),
            coinGeckoTickerIdsFetcher,
            AlphaWalletRemoteTickerIdsFetcher(provider: fileTokenEntriesProvider, tickerIdsFetcher: coinGeckoTickerIdsFetcher)
        ], storage: storage)
        self.config = config
        self.storage = storage
    }

    func ticker(for addressAndPRCServer: AddressAndRPCServer) -> CoinTicker? {
        return storage.ticker(for: addressAndPRCServer)
    }

    func cancel() {
        promises.values.values.forEach { $0.cancel() }
        promises.removeAll()
    }

    func fetchTickers(for tokens: [TokenMappedToTicker], force: Bool = false) {
        let targetTokensToFetchTickers = tokens.filter {
            if promises[$0] != nil {
                return false
            } else {
               return force || hasExpiredTickersLifeTimeSinceLastUpdate(for: $0)
            }
        }

        guard !targetTokensToFetchTickers.isEmpty else {
            debugLog("[CoinGecko] already has load tickers operation")
            return
        }

        //NOTE: use shared loading tickers operation for batch of tokens
        let operation = fetchBatchOfTickers(for: targetTokensToFetchTickers)
            .sink(receiveCompletion: { [promises] _ in
                for token in targetTokensToFetchTickers {
                    promises.removeValue(forKey: token)
                }
            }, receiveValue: { [storage, weak self] tickers in
                storage.addOrUpdate(tickers: tickers)

                for token in targetTokensToFetchTickers {
                    self?.setLastTickerUpdateDate(date: Date(), for: token)
                }
            })

        debugLog("[CoinGecko] start fetch tickers for \(targetTokensToFetchTickers.count) tokens")

        for token in targetTokensToFetchTickers {
            promises[token] = operation
        }
    }

    func resolveTikerIds(for tokens: [TokenMappedToTicker]) {
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
    func fetchChartHistories(for token: TokenMappedToTicker, force: Bool, periods: [ChartHistoryPeriod]) -> AnyPublisher<[ChartHistory], Never> {
        let publishers = periods.map { fetchChartHistory(force: force, period: $0, for: token) }

        return Publishers.MergeMany(publishers).collect()
            .map { $0 }
            .eraseToAnyPublisher()
    }

    private func fetchChartHistory(force: Bool, period: ChartHistoryPeriod, for token: TokenMappedToTicker) -> AnyPublisher<ChartHistory, Never> {
        return tickerIdsFetcher.tickerId(for: token)
            .flatMap { [storage, networkProvider, unowned self] tickerId -> AnyPublisher<ChartHistory, Never> in
                guard let tickerId = tickerId.flatMap({ AssignedCoinTickerId(tickerId: $0, token: token) }) else {
                    return .just(.empty)
                }

                if let data = storage.chartHistory(period: period, for: tickerId), !self.hasExpired(history: data, for: period), !force {
                    return .just(data.history)
                } else {
                    debugLog("[CoinGecko] fetch chart history for tickerId: \(tickerId)")
                    return networkProvider.fetchChartHistory(for: period, tickerId: tickerId.tickerId)
                        .handleEvents(receiveOutput: { history in
                            storage.addOrUpdateChartHistory(history: history, period: period, for: tickerId)
                        }).replaceError(with: .empty)
                        .receive(on: RunLoop.main)
                        .eraseToAnyPublisher()
                }
            }.eraseToAnyPublisher()
    }

    private func hasExpiredTickersLifeTimeSinceLastUpdate(for token: TokenMappedToTicker) -> Bool {
        if let lastFetchingDate = tickerUpdatesDates[token], Date().timeIntervalSince(lastFetchingDate) <= pricesCacheLifetime {
            return false
        }
        return true
    }

    private func setLastTickerUpdateDate(date: Date, for token: TokenMappedToTicker) {
        tickerUpdatesDates[token] = date
    }

    private func hasExpired(history mappedChartHistory: MappedChartHistory, for period: ChartHistoryPeriod) -> Bool {
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

    private func fetchBatchOfTickers(for tokens: [TokenMappedToTicker]) -> AnyPublisher<[AssignedCoinTickerId: CoinTicker], CoinGeckoNetworkProviderError> {
        debugLog("[CoinGecko] fetch ticker ids for tokens: \(tokens.map { "\($0.contractAddress)-\($0.server.chainID)-\($0.symbol)" })")

        let publishers = tokens.map { token in
            tickerIdsFetcher.tickerId(for: token).map { $0.flatMap { AssignedCoinTickerId(tickerId: $0, token: token) } }
        }

        return Publishers.MergeMany(publishers).collect()
            .setFailureType(to: CoinGeckoNetworkProviderError.self)
            .flatMap { [networkProvider] tickerIds -> AnyPublisher<[AssignedCoinTickerId: CoinTicker], CoinGeckoNetworkProviderError> in
                let tickerIds = tickerIds.compactMap { $0 }
                let ids = Set(tickerIds.compactMap { $0.tickerId }).joined(separator: ",")
                debugLog("[CoinGecko] fetch tickers for ids: \(ids)")
                return networkProvider.fetchTickers(for: ids).map { tickers in
                    var result: [AssignedCoinTickerId: CoinTicker] = [:]

                    for ticker in tickers {
                        for tickerId in tickerIds.filter({ $0.tickerId == ticker.id }) {
                            result[tickerId] = ticker
                        }
                    }
                    return result
                }.eraseToAnyPublisher()
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
