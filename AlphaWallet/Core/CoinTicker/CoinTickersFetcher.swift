//
//  CoinTickersFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2021.
//

import PromiseKit
import Moya
import SwiftyJSON

struct TokenMappedToTicker: Hashable {
    let symbol: String
    let name: String
    let contractAddress: AlphaWallet.Address
    let server: RPCServer

    init(tokenObject: TokenObject) {
        symbol = tokenObject.symbol
        name = tokenObject.name
        contractAddress = tokenObject.contractAddress
        server = tokenObject.server
    }

    init(token: Activity.AssignedToken) {
        symbol = token.symbol
        name = token.name
        contractAddress = token.contractAddress
        server = token.server
    }
}

protocol CoinTickersFetcherType {
    var tickersSubscribable: Subscribable<[AddressAndRPCServer: CoinTicker]> { get }
    var tickers: [AddressAndRPCServer: CoinTicker] { get }

    func fetchPrices(forTokens tokens: ServerDictionary<[TokenMappedToTicker]>) -> Promise<[AddressAndRPCServer: CoinTicker]>
    func fetchChartHistories(addressToRPCServerKey: AddressAndRPCServer) -> Promise<[ChartHistory]>
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

    private static var fetchSupportedTokensPromise: Promise<[Ticker]>?
    private static var coinGeckoTickers: [Ticker] = []

    private let pricesCacheLifetime: TimeInterval = 60 * 60
    private let dayChartHistoryCacheLifetime: TimeInterval = 60 * 60
    private var isFetchingPrices = false

    var tickersSubscribable: Subscribable<[AddressAndRPCServer: CoinTicker]> = .init(nil)
    var tickers: [AddressAndRPCServer: CoinTicker] {
        return cache.tickers
    }
    private static let queue: DispatchQueue = DispatchQueue(label: "com.CoinTickersFetcher.updateQueue")

    private let provider: MoyaProvider<AlphaWalletService>
    private let config: Config
    private let cache: CoinTickersFetcherCacheType

    private var historyCache: [CoinTicker: [ChartHistoryPeriod: (history: ChartHistory, fetchDate: Date)]] = [:]

    init(provider: MoyaProvider<AlphaWalletService>, config: Config, cache: CoinTickersFetcherCacheType = CoinTickersFetcherFileCache()) {
        self.provider = provider
        self.config = config
        self.cache = cache
    }

    //Important in implementation to not cache the returned promise (which is used to further fetch prices). We only want to cache the promise/request for fetching supported tickers
    private static func fetchSupportedTickers(config: Config, provider: MoyaProvider<AlphaWalletService>, shouldRetry: Bool = true) -> Promise<[Ticker]> {
        if let promise = fetchSupportedTokensPromise { return promise }

        let promise: Promise<[Ticker]> = firstly {
            provider.request(.tokensThatHasPrices(config: config))
        }.map(on: CoinTickersFetcher.queue, { response -> [Ticker] in
            return try response.map([Ticker].self, using: JSONDecoder())
        }).get(on: CoinTickersFetcher.queue, { tickers in
            CoinTickersFetcher.coinGeckoTickers = tickers
        }).recover { _ -> Promise<[Ticker]> in
            if shouldRetry {
                return fetchSupportedTickers(config: config, provider: provider, shouldRetry: false)
            } else {
                return .value([])
            }
        }
        fetchSupportedTokensPromise = promise
        return promise
    }

    private func fetchSupportedTickers() -> Promise<[Ticker]> {
        Self.fetchSupportedTickers(config: config, provider: provider)
    }

    func fetchPrices(forTokens tokens: ServerDictionary<[TokenMappedToTicker]>) -> Promise<[AddressAndRPCServer: CoinTicker]> {
        return firstly {
            fetchTickers(forTokens: tokens)
        }.get { [weak self] tickers, tickerIds in
            self?.cache.tickers = tickers
            self?.cache.lastFetchedTickerIds = tickerIds
            self?.cache.lastFetchedDate = Date()
            self?.tickersSubscribable.value = tickers
        }.map {
            $0.tickers
        }
    }

    func fetchChartHistories(addressToRPCServerKey: AddressAndRPCServer) -> Promise<[ChartHistory]> {
        let promises: [Promise<ChartHistory>] = ChartHistoryPeriod.allCases.map {
            fetchChartHistory(force: false, period: $0, for: addressToRPCServerKey)
        }
        return when(fulfilled: promises)
    }

    private func fetchChartHistory(period: ChartHistoryPeriod, ticker: CoinTicker) -> Promise<ChartHistory> {
        firstly {
            provider.request(.priceHistoryOfToken(config: config, id: ticker.id, currency: Constants.Currency.usd, days: period.rawValue))
        }.map(on: CoinTickersFetcher.queue, { response -> ChartHistory in
            try response.map(ChartHistory.self, using: JSONDecoder())
        }).recover(on: CoinTickersFetcher.queue, { _ -> Promise<ChartHistory> in
            .value(.empty)
        })
    }

    private func cacheChartHistory(result: ChartHistory, period: ChartHistoryPeriod, for ticker: CoinTicker) {
        guard !result.prices.isEmpty else { return }
        var newHistory = cache.historyCache[ticker] ?? [:]
        newHistory[period] = .init(history: result, fetchDate: Date())
        cache.historyCache[ticker] = newHistory
    }

    func fetchChartHistory(force: Bool, period: ChartHistoryPeriod, for key: AddressAndRPCServer, shouldRetry: Bool = true) -> Promise<ChartHistory> {
        firstly {
            getCachedChartHistory(period: period, for: key)
        }.then { values -> Promise<ChartHistory> in
            let ticker = values.ticker
            if let value = values.history, !force {
                return .value(value)
            } else {
                return firstly {
                    self.fetchChartHistory(period: period, ticker: ticker)
                }.get(on: CoinTickersFetcher.queue, {
                    self.cacheChartHistory(result: $0, period: period, for: ticker)
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

    private func getCachedChartHistory(period: ChartHistoryPeriod, for key: AddressAndRPCServer) -> Promise<(ticker: CoinTicker, history: ChartHistory?)> {
        struct TickerNotFound: Swift.Error {
        }
        if let ticker = cache.tickers[key] {
            if let cached = cache.historyCache[ticker]?[period] {
                let hasCacheExpired: Bool
                switch period {
                case .day:
                    let fetchDate = cached.fetchDate
                    hasCacheExpired = Date().timeIntervalSince(fetchDate) > dayChartHistoryCacheLifetime
                case .week, .month, .threeMonth, .year:
                    hasCacheExpired = false
                }
                if hasCacheExpired {
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

    private func fetchTickers(forTokens tokens: ServerDictionary<[TokenMappedToTicker]>) -> Promise<(tickers: [AddressAndRPCServer: CoinTicker], tickerIds: [String])> {
        let tokens = tokens.values.flatMap { $0 }
        guard !isFetchingPrices else { return .init(error: Error.alreadyFetchingPrices) }

        isFetchingPrices = true

        return firstly {
            fetchSupportedTickers()
        }.compactMap(on: CoinTickersFetcher.queue, { tickers -> [MappedCoinTickerId] in
            let mappedTokensToCoinTickerIds = tokens.compactMap { tokenObject -> MappedCoinTickerId? in
                if let ticker = tickers.first(where: { $0.matches(tokenObject: tokenObject) }) {
                    return MappedCoinTickerId(tickerId: ticker.id, contractAddress: tokenObject.contractAddress, server: tokenObject.server)
                } else {
                    return nil
                }
            }
            return mappedTokensToCoinTickerIds
        }).then(on: CoinTickersFetcher.queue, { mapped -> Promise<(tickers: [AddressAndRPCServer: CoinTicker], tickerIds: [String])> in
            let tickerIds: [String] = Set(mapped).map { $0.tickerId }
            let ids: String = tickerIds.joined(separator: ",")
            if let lastFetchedTickers = self.cache.lastFetchedTickerIds, let lastFetchingDate = self.cache.lastFetchedDate, lastFetchedTickers.containsSameElements(as: tickerIds) {
                if Date().timeIntervalSince(lastFetchingDate) <= self.pricesCacheLifetime {
                    return .value((tickers: self.cache.tickers, tickerIds: tickerIds))
                } else {
                    //no-op
                }
            }
            return self.fetchPrices(ids: ids, mappedCoinTickerIds: mapped, tickerIds: tickerIds).map { (tickers: $0, tickerIds: tickerIds) }
        }).ensure(on: CoinTickersFetcher.queue, { [weak self] in
            self?.isFetchingPrices = false
        })
    }

    private func fetchPrices(ids: String, mappedCoinTickerIds: [MappedCoinTickerId], tickerIds: [String]) -> Promise<[AddressAndRPCServer: CoinTicker]> {
        var page = 1
        var allResults: [AddressAndRPCServer: CoinTicker] = .init()
        func fetchPageImpl() -> Promise<[AddressAndRPCServer: CoinTicker]> {
            return firstly {
                fetchPricesPage(ids: ids, mappedCoinTickerIds: mappedCoinTickerIds, tickerIds: tickerIds, page: page, shouldRetry: true)
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

    private func fetchPricesPage(ids: String, mappedCoinTickerIds: [MappedCoinTickerId], tickerIds: [String], page: Int, shouldRetry: Bool) -> Promise<[AddressAndRPCServer: CoinTicker]> {
        firstly {
            provider.request(.pricesOfTokens(config: config, ids: ids, currency: Constants.Currency.usd, page: page))
        }.map(on: CoinTickersFetcher.queue, { response -> [AddressAndRPCServer: CoinTicker] in
            let tickers = try response.map([CoinTicker].self, using: JSONDecoder())
            var resultTickers: [AddressAndRPCServer: CoinTicker] = [:]
            for ticker in tickers {
                if let value = mappedCoinTickerIds.first(where: { $0.tickerId == ticker.id }) {
                    let key = AddressAndRPCServer(address: value.contractAddress, server: value.server)
                    resultTickers[key] = ticker
                }
            }
            return resultTickers
        }).then(on: CoinTickersFetcher.queue, { tickers -> Promise<[AddressAndRPCServer: CoinTicker]> in
            return .value(tickers)
        }).recover(on: CoinTickersFetcher.queue, { _ -> Promise<[AddressAndRPCServer: CoinTicker]> in
            if shouldRetry {
                return self.fetchPricesPage(ids: ids, mappedCoinTickerIds: mappedCoinTickerIds, tickerIds: tickerIds, page: page, shouldRetry: false)
            } else {
                return .value(.init())
            }
        })
    }
}

fileprivate struct Ticker: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case platforms
    }

    //https://polygonscan.com/address/0x0000000000000000000000000000000000001010
    static private let polygonMaticContract = AlphaWallet.Address(string: "0x0000000000000000000000000000000000001010")!

    let id: String
    let symbol: String
    let name: String
    let platforms: [String: AlphaWallet.Address]

    func matches(tokenObject: TokenMappedToTicker) -> Bool {
        //We just filter out those that we don't think are supported by the API. One problem this helps to alleviate is in the API output, certain tickers have a non-empty platform yet the platform list might not be complete, eg. Ether on Ethereum mainnet:
        //{
        //   "symbol" : "eth",
        //   "id" : "ethereum",
        //   "name" : "Ethereum",
        //   "platforms" : {
        //      "huobi-token" : "0x64ff637fb478863b7468bc97d30a5bf3a428a1fd",
        //      "binance-smart-chain" : "0x2170ed0880ac9a755fd29b2688956bd959f933f8"
        //   }
        //},
        //This means we can only match solely by symbol, ignoring platform matches. But this means it's easy to match the wrong ticker (by symbol only). Hence, we at least remove those chains we don't think are supported
        guard isServerSupported(tokenObject.server) else { return false }
        if let (_, contract) = platforms.first(where: { platformMatches($0.key, server: tokenObject.server) }) {
            if contract.sameContract(as: Constants.nullAddress) {
                return symbol.localizedLowercase == tokenObject.symbol.localizedLowercase
            } else if contract.sameContract(as: tokenObject.contractAddress) {
                return true
            } else if tokenObject.server == .polygon && tokenObject.contractAddress == Constants.nativeCryptoAddressInDatabase && contract.sameContract(as: Self.polygonMaticContract) {
                return true
            } else {
                return false
            }
        } else {
            return symbol.localizedLowercase == tokenObject.symbol.localizedLowercase && name.localizedLowercase == tokenObject.name.localizedLowercase
        }
    }

    init(from decoder: Decoder) throws {
        enum AnyError: Swift.Error {
            case invalid
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        platforms = container.decode([String: String].self, forKey: .platforms, defaultValue: [:]).compactMapValues { str in
            if str.isEmpty {
                //CoinGecko returns nullAddress as the value (contract) in `platforms` for tokens is sometimes an empty string: `"platforms" : { "ethereum" : "" }`, so we use the 0x0..0 address to represent them
                return Constants.nullAddress
            } else {
                return AlphaWallet.Address(string: str)
            }
        }
    }

    //Mapping created by examining CoinGecko API output empirically
    private func platformMatches(_ platform: String, server: RPCServer) -> Bool {
        switch server {
        case .main: return platform == "ethereum"
        case .classic: return platform == "ethereum-classic"
        case .xDai: return platform == "xdai"
        case .binance_smart_chain: return platform == "binance-smart-chain"
        case .avalanche: return platform == "avalanche"
        case .polygon: return platform == "polygon-pos"
        case .fantom: return platform == "fantom"
        case .poa, .kovan, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .ropsten, .rinkeby, .heco, .heco_testnet, .fantom_testnet, .avalanche_testnet, .mumbai_testnet, .custom, .optimistic, .optimisticKovan:
            return false
        }
    }

    private func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main: return true
        case .classic: return true
        case .xDai: return true
        case .binance_smart_chain: return true
        case .avalanche: return true
        case .polygon: return true
        case .poa, .kovan, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .ropsten, .rinkeby, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche_testnet, .mumbai_testnet, .custom, .optimistic, .optimisticKovan:
            return false
        }
    }
}

fileprivate extension Array where Element == String {
    func containsSameElements(as other: [Element]) -> Bool {
        let me = Set(self)
        let other = Set(other)
        return me == other
    }
}
