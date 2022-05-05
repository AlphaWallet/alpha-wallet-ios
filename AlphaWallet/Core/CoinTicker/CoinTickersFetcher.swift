//
//  CoinTickersFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2021.
//

import PromiseKit
import Moya
import Combine
import Foundation

protocol CoinTickersFetcherType: AnyObject {
    var tickersUpdatedPublisher: AnyPublisher<Void, Never> { get }

    func ticker(for addressAndPRCServer: AddressAndRPCServer) -> CoinTicker?
    func fetchPrices(forTokens tokens: [TokenMappedToTicker])
    func fetchChartHistories(addressToRPCServerKey: AddressAndRPCServer, force: Bool, periods: [ChartHistoryPeriod]) -> Promise<[ChartHistory]>
}

fileprivate struct MappedCoinTickerId: Hashable {
    let tickerId: String
    let contractAddress: AlphaWallet.Address
    let server: RPCServer
}

class CoinTickersFetcher: CoinTickersFetcherType {
    enum Error: Swift.Error {
        case alreadyFetchingPrices
    }

    private var fetchSupportedTickerIdsPromise: Promise<[TickerId]>?

    private let pricesCacheLifetime: TimeInterval = 60 * 60
    private let dayChartHistoryCacheLifetime: TimeInterval = 60 * 60
    private var isFetchingPrices = false

    var tickersUpdatedPublisher: AnyPublisher<Void, Never> {
        return cache
            .tickersPublisher
            .map { _ in }
            .eraseToAnyPublisher()
    }

    private static let queue: DispatchQueue = DispatchQueue(label: "com.CoinTickersFetcher.updateQueue")

    private let provider: MoyaProvider<AlphaWalletService>
    private let config: Config
    private let cache: CoinTickersFetcherCacheType

    init(provider: MoyaProvider<AlphaWalletService>, config: Config, cache: CoinTickersFetcherCacheType = CoinTickersFetcherFileCache()) {
        self.provider = provider
        self.config = config
        self.cache = cache
    }

    func ticker(for addressAndPRCServer: AddressAndRPCServer) -> CoinTicker? {
        //NOTE: If it doesn't include the price for the native token, hardwire it to use Ethereum's mainnet's native token price.
        if addressAndPRCServer.server == .arbitrum && addressAndPRCServer.address.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            let overriddenAddressAndPRCServer: AddressAndRPCServer = .init(address: Constants.nativeCryptoAddressInDatabase, server: .main)
            return cache.tickers[overriddenAddressAndPRCServer]
        } else {
            return cache.tickers[addressAndPRCServer]
        }
    }

    //Important in implementation to not cache the returned promise (which is used to further fetch prices). We only want to cache the promise/request for fetching supported tickers
    private func fetchSupportedTickerIds(shouldRetry: Bool = true) -> Promise<[TickerId]> {
        if let promise = fetchSupportedTickerIdsPromise { return promise }

        let promise: Promise<[TickerId]> = firstly {
            provider.request(.tokensThatHasPrices)
        }.map(on: CoinTickersFetcher.queue, { response -> [TickerId] in
            return try response.map([TickerId].self, using: JSONDecoder())
        }).recover { _ -> Promise<[TickerId]> in
            if shouldRetry {
                return self.fetchSupportedTickerIds(shouldRetry: false)
            } else {
                return .value([])
            }
        }
        fetchSupportedTickerIdsPromise = promise
        return promise
    }

    func fetchPrices(forTokens tokens: [TokenMappedToTicker]) {
        firstly {
            fetchTickers(forTokens: tokens)
        }.done { [weak cache] tickers, tickerIds in
            cache?.tickers = tickers
            cache?.lastFetchedTickerIds = tickerIds
            cache?.lastFetchedDate = Date()
        }.cauterize()
    }

    func fetchChartHistories(addressToRPCServerKey addressAndPRCServer: AddressAndRPCServer, force: Bool, periods: [ChartHistoryPeriod]) -> Promise<[ChartHistory]> {
        let addressToRPCServerKey: AddressAndRPCServer
        //NOTE: If it doesn't include the price for the native token, hardwire it to use Ethereum's mainnet's native token price.
        if addressAndPRCServer.server == .arbitrum && addressAndPRCServer.address.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            addressToRPCServerKey = .init(address: Constants.nativeCryptoAddressInDatabase, server: .main)
        } else {
            addressToRPCServerKey = addressAndPRCServer
        }

        let promises: [Promise<ChartHistory>] = periods.map {
            fetchChartHistory(force: force, period: $0, for: addressToRPCServerKey)
        }
        return when(fulfilled: promises)
    }

    private func fetchChartHistory(period: ChartHistoryPeriod, ticker: CoinTicker) -> Promise<ChartHistory> {
        firstly {
            provider.request(.priceHistoryOfToken(id: ticker.id, currency: Constants.Currency.usd, days: period.rawValue))
        }.map(on: CoinTickersFetcher.queue, { response -> ChartHistory in
            try response.map(ChartHistory.self, using: JSONDecoder())
        }).recover(on: CoinTickersFetcher.queue, { _ -> Promise<ChartHistory> in
            .value(.empty)
        })
    }

    func fetchChartHistory(force: Bool, period: ChartHistoryPeriod, for key: AddressAndRPCServer, shouldRetry: Bool = true) -> Promise<ChartHistory> {
        firstly {
            cache.getCachedChartHistory(period: period, for: key, dayChartHistoryCacheLifetime: dayChartHistoryCacheLifetime)
        }.then { values -> Promise<ChartHistory> in
            let ticker = values.ticker
            if let value = values.history, !force {
                return .value(value)
            } else {
                return firstly {
                    self.fetchChartHistory(period: period, ticker: ticker)
                }.get(on: CoinTickersFetcher.queue, {
                    self.cache.cacheChartHistory(result: $0, period: period, for: ticker)
                })
            }
        }.recover { _ -> Promise<ChartHistory> in
            if shouldRetry {
                return self.fetchChartHistory(force: force, period: period, for: key, shouldRetry: false)
            } else {
                struct FetchChartHistoryError: Swift.Error {}
                throw FetchChartHistoryError()
            }
        }
    }

    private func fetchTickers(forTokens tokens: [TokenMappedToTicker]) -> Promise<(tickers: [AddressAndRPCServer: CoinTicker], tickerIds: [String])> {

        let cache = self.cache
        let pricesCacheLifetime = self.pricesCacheLifetime
        let provider = self.provider
        let config = self.config
        let spamTokens = SpamTokens()
        let tickerIdFilter = TickerIdFilter()

        return firstly {
            fetchSupportedTickerIds()
        }.compactMap(on: CoinTickersFetcher.queue, { tickerIds -> [MappedCoinTickerId] in
            let mappedTokensToCoinTickerIds = tokens.compactMap { token -> MappedCoinTickerId? in
               let spamNeedle = AddressAndRPCServer(address: token.contractAddress, server: token.server)
                if spamTokens.isSpamToken(spamNeedle) {
                    return nil
                }

                if let tickerId = tickerIds.first(where: { tickerIdFilter.matches(token: token, tickerId: $0) }) {
                    let tickerId = token.overridenCoinGeckoTickerId(tickerId: tickerId.id)
                    return MappedCoinTickerId(tickerId: tickerId, contractAddress: token.contractAddress, server: token.server)
                } else {
                    return nil
                }
            }
            return mappedTokensToCoinTickerIds
        }).then(on: CoinTickersFetcher.queue, { mapped -> Promise<(tickers: [AddressAndRPCServer: CoinTicker], tickerIds: [String])> in
            let tickerIds: [String] = Set(mapped).map { $0.tickerId }
            let ids: String = tickerIds.joined(separator: ",")
            if let lastFetchedTickers = cache.lastFetchedTickerIds, let lastFetchingDate = cache.lastFetchedDate, lastFetchedTickers.containsSameElements(as: tickerIds) {
                if Date().timeIntervalSince(lastFetchingDate) <= pricesCacheLifetime {
                    return .value((tickers: cache.tickers, tickerIds: tickerIds))
                } else {
                    //no-op
                }
            }
            return Self.fetchPrices(provider: provider, config: config, ids: ids, mappedCoinTickerIds: mapped, tickerIds: tickerIds).map { (tickers: $0, tickerIds: tickerIds) }
        })
    }

    private static func fetchPrices(provider: MoyaProvider<AlphaWalletService>, config: Config, ids: String, mappedCoinTickerIds: [MappedCoinTickerId], tickerIds: [String]) -> Promise<[AddressAndRPCServer: CoinTicker]> {
        var page = 1
        var allResults: [AddressAndRPCServer: CoinTicker] = .init()
        func fetchPageImpl() -> Promise<[AddressAndRPCServer: CoinTicker]> {
            return firstly {
                fetchPricesPage(provider: provider, config: config, ids: ids, mappedCoinTickerIds: mappedCoinTickerIds, tickerIds: tickerIds, page: page, shouldRetry: true)
            }.then { results -> Promise<[AddressAndRPCServer: CoinTicker]> in
                if results.isEmpty {
                    return Promise<[AddressAndRPCServer: CoinTicker]>.value(allResults)
                } else {
                    allResults.merge(results) { _, new in new }
                    page += 1
                    return fetchPageImpl()
                }
            }
        }
        return fetchPageImpl()
    }

    private static func fetchPricesPage(provider: MoyaProvider<AlphaWalletService>, config: Config, ids: String, mappedCoinTickerIds: [MappedCoinTickerId], tickerIds: [String], page: Int, shouldRetry: Bool) -> Promise<[AddressAndRPCServer: CoinTicker]> {
        firstly {
            provider.request(.pricesOfTokens(ids: ids, currency: Constants.Currency.usd, page: page))
        }.map(on: CoinTickersFetcher.queue, { response -> [AddressAndRPCServer: CoinTicker] in
            let tickers = try response.map([CoinTicker].self, using: JSONDecoder())
            var resultTickers: [AddressAndRPCServer: CoinTicker] = [:]
            for ticker in tickers {
                let matches = mappedCoinTickerIds.filter({ $0.tickerId == ticker.id })
                for each in matches {
                    let key = AddressAndRPCServer(address: each.contractAddress, server: each.server)
                    resultTickers[key] = ticker
                }
            }
            return resultTickers
        }).then(on: CoinTickersFetcher.queue, { tickers -> Promise<[AddressAndRPCServer: CoinTicker]> in
            return .value(tickers)
        }).recover(on: CoinTickersFetcher.queue, { _ -> Promise<[AddressAndRPCServer: CoinTicker]> in
            if shouldRetry {
                return fetchPricesPage(provider: provider, config: config, ids: ids, mappedCoinTickerIds: mappedCoinTickerIds, tickerIds: tickerIds, page: page, shouldRetry: false)
            } else {
                return .value(.init())
            }
        })
    }
}

fileprivate extension Array where Element == String {
    func containsSameElements(as other: [Element]) -> Bool {
        let me = Set(self)
        let other = Set(other)
        return me == other
    }
}
