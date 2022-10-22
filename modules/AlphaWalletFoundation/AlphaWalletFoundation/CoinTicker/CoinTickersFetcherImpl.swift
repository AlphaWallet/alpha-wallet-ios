//
//  BaseCoinTickersFetcher.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 15.09.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public protocol CoinTickersFetcherProvider {
    func fetchTickers(for tokens: [TokenMappedToTicker], force: Bool)
    func resolveTikerIds(for tokens: [TokenMappedToTicker])
    func fetchChartHistories(for token: TokenMappedToTicker, force: Bool, periods: [ChartHistoryPeriod]) -> AnyPublisher<[ChartHistory], Never>
    func cancel()
}

public final class CoinTickersFetcherImpl: CoinTickersFetcher {
    private var providers: AtomicArray<CoinTickersFetcherProvider> = .init()
    private let storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage

    public init(providers: [CoinTickersFetcherProvider], storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage) {
        self.providers.set(array: providers)
        self.storage = storage
    }

    public convenience init() {
        let storage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage
        if isRunningTests() {
            storage = RealmStore(realm: fakeRealm(), name: "org.alphawallet.swift.realmStore.shared.wallet")
        } else {
            storage = RealmStore.shared
        }

        self.init(providers: [
            CoinGeckoTickersFetcher(storage: storage),
            PhiCoinTickersFetcher(storage: storage)
        ], storage: storage)
    }
    
    public var tickersDidUpdate: AnyPublisher<Void, Never> {
        return storage.tickersDidUpdate
    }

    public var updateTickerIds: AnyPublisher<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never> {
        storage.updateTickerIds
    }

    public func ticker(for addressAndPRCServer: AddressAndRPCServer) -> CoinTicker? {
        return storage.ticker(for: addressAndPRCServer)
    }

    public func addOrUpdateTestsOnly(ticker: CoinTicker?, for token: TokenMappedToTicker) {
        let tickers: [AssignedCoinTickerId: CoinTicker] = ticker.flatMap { ticker in
            let tickerId = AssignedCoinTickerId(tickerId: "tickerId-\(token.contractAddress)-\(token.server.chainID)", token: token)
            return [tickerId: ticker]
        } ?? [:]

        storage.addOrUpdate(tickers: tickers)
    }

    private struct ElementsMappedToProvider<T: CoinTickerServiceIdentifieble> {
        let provider: CoinTickersFetcherProvider
        let elements: [T]
    }

    private func elementMappedToProvider<T: CoinTickerServiceIdentifieble>(for element: T) -> ElementsMappedToProvider<T>? {
        elementsMappedToProvider(for: [element])
            .first
    }

    private func elementsMappedToProvider<T: CoinTickerServiceIdentifieble>(for elements: [T]) -> [ElementsMappedToProvider<T>] {
        var mappedToProvidersTypeTokens: [String: [T]] = [:]
        for each in elements {
            let type = String(describing: each.coinTickerProviderType)
            var tokens = mappedToProvidersTypeTokens[type] ?? []
            tokens += [each]

            mappedToProvidersTypeTokens[type] = tokens
        }

        func providerName(_ provider: CoinTickersFetcherProvider) -> String {
            return String(describing: provider).components(separatedBy: ".").last!
        }

        return mappedToProvidersTypeTokens.compactMap { mapped -> ElementsMappedToProvider<T>? in
            guard let provider = providers.first(where: { providerName($0) == mapped.key }) else { return nil }
            return ElementsMappedToProvider(provider: provider, elements: mapped.value)
        }
    }

    public func fetchTickers(for tokens: [TokenMappedToTicker], force: Bool) {
        for each in elementsMappedToProvider(for: tokens) {
            guard !each.elements.isEmpty else { continue }
            each.provider.fetchTickers(for: each.elements, force: force)
        }
    }

    public func resolveTikerIds(for tokens: [TokenMappedToTicker]) {
        for each in elementsMappedToProvider(for: tokens) {
            guard !each.elements.isEmpty else { continue }
            each.provider.resolveTikerIds(for: each.elements)
        }
    }

    public func fetchChartHistories(for token: TokenMappedToTicker, force: Bool, periods: [ChartHistoryPeriod]) -> AnyPublisher<[ChartHistory], Never> {
        guard let publisher = elementMappedToProvider(for: token)
            .flatMap({ $0.provider.fetchChartHistories(for: token, force: force, periods: periods) }) else { return .empty() }

        return publisher
    }

    public func cancel() {
        providers.forEach { $0.cancel() }
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
    var coinTickerProviderType: CoinTickersFetcherProvider.Type {
        switch server {
        case .main, .classic, .callisto, .kovan, .ropsten, .custom, .rinkeby, .poa, .sokol, .goerli, .xDai, .artis_sigma1, .binance_smart_chain, .binance_smart_chain_testnet, .artis_tau1, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .candle, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .ioTeX, .ioTeXTestnet, .optimismGoerli, .arbitrumGoerli, .cronosMainnet:
            return CoinGeckoTickersFetcher.self
        case .phi, .phi2:
            return PhiCoinTickersFetcher.self
        }
    }
}
