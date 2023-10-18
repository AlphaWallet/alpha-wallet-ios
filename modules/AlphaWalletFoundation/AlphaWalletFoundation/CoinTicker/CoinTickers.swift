// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore

public final class CoinTickers {
    private let fetchers: AtomicArray<CoinTickersFetcher> = .init()
    private let storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage
    private var chartHistories: [TokenMappedToTicker: Task<[ChartHistoryPeriod: ChartHistory], Never>] = .init()
    private var cancelable = Set<AnyCancellable>()

    public init(fetchers: [CoinTickersFetcher], storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage) {
        self.fetchers.set(array: fetchers)
        self.storage = storage
    }

    public convenience init(transporter: ApiTransporter, analytics: AnalyticsLogger) {
        let storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage
        if isRunningTests() {
            //TODO should be injected in tests instead
            storage = RealmStore(config: fakeRealmConfiguration(), name: "org.alphawallet.swift.realmStore.shared.wallet")
        } else {
            storage = RealmStore.shared
        }

        self.init(fetchers: [CoinGeckoTickersFetcher(storage: storage, transporter: transporter, analytics: analytics)], storage: storage)
    }

    enum functional {}
}

extension CoinTickers: CoinTickersFetcher {
    public func fetchTickers(for tokens: [TokenMappedToTicker], force: Bool, currency: Currency) {
        for each in functional.createFetcherToTokenMappedToTickerPairs(for: tokens, fetchers: fetchers) {
            guard !each.tokenMappedToTickers.isEmpty else { continue }
            each.fetcher.fetchTickers(for: each.tokenMappedToTickers, force: force, currency: currency)
        }
    }

    public func resolveTickerIds(for tokens: [TokenMappedToTicker]) {
        for each in functional.createFetcherToTokenMappedToTickerPairs(for: tokens, fetchers: fetchers) {
            guard !each.tokenMappedToTickers.isEmpty else { continue }
            each.fetcher.resolveTickerIds(for: each.tokenMappedToTickers)
        }
    }

    public func fetchChartHistories(for token: TokenMappedToTicker, force: Bool, periods: [ChartHistoryPeriod], currency: Currency) async -> [ChartHistoryPeriod: ChartHistory] {
        if let fetcher = functional.getFetcher(forTokenMappedToTicker: token, fetchers: fetchers) {
            return await fetcher.fetchChartHistories(for: token, force: force, periods: periods, currency: currency)
        } else {
            return [:]
        }
    }

    //TODO this isn't called?
    public func cancel() {
        fetchers.forEach { $0.cancel() }
    }
}

extension CoinTickers: CoinTickersProvider {
    public var tickersDidUpdate: AnyPublisher<Void, Never> {
        return storage.tickersDidUpdate
    }

    public var updateTickerIds: AnyPublisher<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never> {
        storage.updateTickerIds
    }

    public func ticker(for key: AddressAndRPCServer, currency: Currency) async -> CoinTicker? {
        return await storage.ticker(for: key, currency: currency)
    }

    public func addOrUpdateTestsOnly(ticker: CoinTicker?, for token: TokenMappedToTicker) -> Task<Void, Never> {
        let tickers: [AssignedCoinTickerId: CoinTicker] = ticker.flatMap { ticker in
            let tickerId = AssignedCoinTickerId(tickerId: "tickerId-\(token.contractAddress)-\(token.server.chainID)", token: token)
            return [tickerId: ticker]
        } ?? [:]

        return storage.addOrUpdate(tickers: tickers)
    }

    public func chartHistories(for token: TokenMappedToTicker, currency: Currency) async -> [ChartHistoryPeriod: ChartHistory] {
        guard let fetcher = functional.getFetcher(forTokenMappedToTicker: token, fetchers: fetchers) else { return [:] }
        if let tokenAndChartHistories = chartHistories[token] {
            return await tokenAndChartHistories.value
        } else {
            let task = Task<[ChartHistoryPeriod: ChartHistory], Never> {
                await fetchChartHistories(for: token, force: false, periods: ChartHistoryPeriod.allCases, currency: currency)
            }
            chartHistories[token] = task
            return await task.value
        }
    }
}

fileprivate extension CoinTickers.functional {
    struct FetcherTokenMappedToTickerPair {
        let fetcher: CoinTickersFetcher
        let tokenMappedToTickers: [TokenMappedToTicker]
    }

    static func getFetcher(forTokenMappedToTicker tokenMappedToTicker: TokenMappedToTicker, fetchers: AtomicArray<CoinTickersFetcher>) -> CoinTickersFetcher? {
        createFetcherToTokenMappedToTickerPairs(for: [tokenMappedToTicker], fetchers: fetchers).first?.fetcher
    }

    static func createFetcherToTokenMappedToTickerPairs(for tokenMappedToTickers: [TokenMappedToTicker], fetchers: AtomicArray<CoinTickersFetcher>) -> [FetcherTokenMappedToTickerPair] {
        var mappedToProvidersTypeTokens: [String: [TokenMappedToTicker]] = [:]
        for each in tokenMappedToTickers {
            //TODO fragile
            let type = String(describing: each.coinTickerProviderType)
            var tokens = mappedToProvidersTypeTokens[type] ?? []
            tokens += [each]
            mappedToProvidersTypeTokens[type] = tokens
        }

        return mappedToProvidersTypeTokens.compactMap { mapped -> FetcherTokenMappedToTickerPair? in
            guard let fetcher = fetchers.first(where: { getFetcherName($0) == mapped.key }) else { return nil }
            return FetcherTokenMappedToTickerPair(fetcher: fetcher, tokenMappedToTickers: mapped.value)
        }
    }

    static func getFetcherName(_ fetcher: CoinTickersFetcher) -> String {
        //TODO fragile
        return String(describing: fetcher).components(separatedBy: ".").last!
    }
}

extension TokenMappedToTicker: CoinTickerServiceIdentifieble {}
extension AddressAndRPCServer: CoinTickerServiceIdentifieble {
    var contractAddress: AlphaWallet.Address { address }
}

private protocol CoinTickerServiceIdentifieble {
    var contractAddress: AlphaWallet.Address { get }
    var server: RPCServer { get }
}

extension CoinTickerServiceIdentifieble {
    var coinTickerProviderType: CoinTickersFetcher.Type {
        switch server {
        case .main, .classic, .callisto, .custom, .goerli, .xDai, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .cronosTestnet, .arbitrum, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .optimismGoerli, .arbitrumGoerli, .cronosMainnet, .okx, .sepolia:
            return CoinGeckoTickersFetcher.self
        }
    }
}
