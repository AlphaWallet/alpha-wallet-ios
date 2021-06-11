//
//  CoinTickersFetcherCache.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import UIKit

protocol CoinTickersFetcherCacheType: class {
    var tickers: [AddressAndRPCServer: CoinTicker] { get set }
    var historyCache: [CoinTicker: [ChartHistoryPeriod: MappedChartHistory]] { get set }
    var lastFetchedDate: Date? { get set }
    var lastFetchedTickerIds: [String]? { get set }
}

class CoinTickersFetcherFileCache: NSObject, CoinTickersFetcherCacheType {

    private let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private (set) lazy var tickersJsonPath: URL = documentDirectory.appendingPathComponent("tickers.json")
    private (set) lazy var historyJsonPath: URL = documentDirectory.appendingPathComponent("history.json")
    private let defaults: UserDefaults = .standard
    
    private enum Keys {
        static let lastFetchedDateKey = "lastFetchedDateKey"
        static let lastFetchedTickerIdsKey = "lastFetchedTickerIdsKey"
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

    var tickers: [AddressAndRPCServer: CoinTicker] {
        get {
            load(url: tickersJsonPath, defaultValue: [:])
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }

            save(data: data, url: tickersJsonPath)
        }
    }

    var historyCache: [CoinTicker: [ChartHistoryPeriod: MappedChartHistory]] {
        get {
            load(url: historyJsonPath, defaultValue: [:])
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }

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

}
