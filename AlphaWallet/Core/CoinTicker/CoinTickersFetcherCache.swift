//
//  CoinTickersFetcherCache.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import Foundation
import PromiseKit

protocol CoinTickersFetcherCacheType: AnyObject {
    var tickers: [AddressAndRPCServer: CoinTicker] { get set }
    var historyCache: [CoinTicker: [ChartHistoryPeriod: MappedChartHistory]] { get set }
    var lastFetchedDate: Date? { get set }
    var lastFetchedTickerIds: [String]? { get set }
    var tickersSubscribable: Subscribable<[AddressAndRPCServer: CoinTicker]> { get }

    func getCachedChartHistory(period: ChartHistoryPeriod, for key: AddressAndRPCServer, dayChartHistoryCacheLifetime: TimeInterval) -> Promise<(ticker: CoinTicker, history: ChartHistory?)>
    func cacheChartHistory(result: ChartHistory, period: ChartHistoryPeriod, for ticker: CoinTicker)
}

class CoinTickersFetcherFileCache: NSObject, CoinTickersFetcherCacheType {

    private let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private (set) lazy var tickersJsonPath: URL = documentDirectory.appendingPathComponent("tickers.json")
    private (set) lazy var historyJsonPath: URL = documentDirectory.appendingPathComponent("history.json")
    private let defaults: UserDefaults = .standardOrForTests

    private enum Keys {
        static let lastFetchedDateKey = "lastFetchedDateKey"
        static let lastFetchedTickerIdsKey = "lastFetchedTickerIdsKey"
    }

    let tickersSubscribable: Subscribable<[AddressAndRPCServer: CoinTicker]> = .init(nil)

    func cacheChartHistory(result: ChartHistory, period: ChartHistoryPeriod, for ticker: CoinTicker) {
        guard !result.prices.isEmpty else { return }
        var newHistory = historyCache[ticker] ?? [:]
        newHistory[period] = .init(history: result, fetchDate: Date())
        historyCache[ticker] = newHistory
    }

    func getCachedChartHistory(period: ChartHistoryPeriod, for key: AddressAndRPCServer, dayChartHistoryCacheLifetime: TimeInterval) -> Promise<(ticker: CoinTicker, history: ChartHistory?)> {
        struct TickerNotFound: Swift.Error {
        }
        if let ticker = tickers[key] {
            if let cached = historyCache[ticker]?[period] {
                let hasCacheExpired: Bool
                switch period {
                case .day:
                    let fetchDate = cached.fetchDate
                    hasCacheExpired = Date().timeIntervalSince(fetchDate) > dayChartHistoryCacheLifetime
                case .week, .month, .threeMonth, .year:
                    hasCacheExpired = false
                }
                if hasCacheExpired || cached.history.prices.isEmpty {
                    //TODO improve by returning the cached value and returning again after refetching. Harder to do with current implement because promises only resolves once. Maybe the Promise's type should be a subscribable?
                    return .value((ticker: ticker, history: nil))
                } else {
                    return .value((ticker: ticker, history: cached.history))
                }
            } else {
                return .value((ticker: ticker, history: nil))
            }
        } else {
            return .init(error: TickerNotFound())
        }
    }

    var lastFetchedTickerIds: [String]? {
        get {
            guard let ids = defaults.value(forKey: Keys.lastFetchedTickerIdsKey) as? [String] else { return nil }
            return ids
        }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.lastFetchedTickerIdsKey)
            } else {
                defaults.removeObject(forKey: Keys.lastFetchedTickerIdsKey)
            }
        }
    }

    var lastFetchedDate: Date? {
        get {
            guard let timeinterval = defaults.value(forKey: Keys.lastFetchedDateKey) as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: timeinterval)
        }
        set {
            if let value = newValue {
                defaults.set(value.timeIntervalSince1970, forKey: Keys.lastFetchedDateKey)
            } else {
                defaults.removeObject(forKey: Keys.lastFetchedDateKey)
            }
        }
    }

    //NOTE: in memory cache, should avoid crash while fetching tickers from file, `malloc: can't allocate region` received one time
    var tickers: [AddressAndRPCServer: CoinTicker] {
        get {
            if let value = tickersSubscribable.value {
                return value
            } else {
                let value: [AddressAndRPCServer: CoinTicker] = load(url: tickersJsonPath, defaultValue: [:])
                tickersSubscribable.value = value
                return value
            }
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }

            save(data: data, url: tickersJsonPath)
            tickersSubscribable.value = newValue
        }
    }

    private var _historyCache: [CoinTicker: [ChartHistoryPeriod: MappedChartHistory]]?

    var historyCache: [CoinTicker: [ChartHistoryPeriod: MappedChartHistory]] {
        get {
            if let value = _historyCache {
                return value
            } else {
                let value: [CoinTicker: [ChartHistoryPeriod: MappedChartHistory]] = load(url: historyJsonPath, defaultValue: [:])
                _historyCache = value

                return value
            }
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }

            _historyCache = newValue
            save(data: data, url: historyJsonPath)
        }
    }

    private func load<T: Codable>(url: URL, defaultValue: T) -> T {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
            return defaultValue
        }

        guard let tickers = try? JSONDecoder().decode(T.self, from: data) else {
            //NOTE: in case if decoding error appears, remove existed file
            try? FileManager.default.removeItem(at: url)

            return defaultValue
        }

        return tickers
    }

    private func save(data: Data, url: URL) {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            // Handle error
        }
    }

    override init() {
        super .init()
        tickersSubscribable.value = load(url: tickersJsonPath, defaultValue: [:])
        _historyCache = load(url: historyJsonPath, defaultValue: [:])
    }

}
