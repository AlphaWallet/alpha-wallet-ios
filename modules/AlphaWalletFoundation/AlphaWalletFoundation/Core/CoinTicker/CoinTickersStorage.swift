//
//  CoinTickersFetcherCache.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import Combine
import AlphaWalletCore

public typealias TickerIdString = String

public protocol CoinTickersStorage {
    var tickersDidUpdate: AnyPublisher<Void, Never> { get }

    func ticker(for addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
    func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker])
}

public protocol ChartHistoryStorage {
    func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId) -> MappedChartHistory?
    func addOrUpdateChartHistory(history: ChartHistory, period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId)
}

public protocol TickerIdsStorage {
    var tickerIds: [TickerId] { get }
    var updateTickerId: AnyPublisher<(tickerId: TickerIdString, key: AddressAndRPCServer), Never> { get }

    func hasTickerIds() -> Bool
    func knownTickerId(for key: TokenMappedToTicker) -> TickerIdString?
    func addOrUpdate(tickerId: TickerIdString?, for key: TokenMappedToTicker)
    func addOrUpdate(tickerIds: [TickerId])
    func removeTickerIds()
}

public class CoinTickersFileStorage: NSObject {
    private let historyStore: Storage<[AssignedCoinTickerId: [ChartHistoryPeriod: MappedChartHistory]]>
    private let tickersStore: Storage<[AssignedCoinTickerId: CoinTicker]>
    private let allTickersIdsStore: Storage<[TickerId]>
    private let knownTickersIdsStore: Storage<[AddressAndRPCServer: TickerIdString]>
    private let updateTickerIdSubject: PassthroughSubject<(tickerId: TickerIdString, key: AddressAndRPCServer), Never> = .init()

    public init(config: Config, storage: StorageType) {
        historyStore = .init(fileName: "history", storage: storage, defaultValue: [:])
        allTickersIdsStore = .init(fileName: "tickersIds", storage: storage, defaultValue: [])
        tickersStore = .init(fileName: "tickers", storage: storage, defaultValue: [:])
        knownTickersIdsStore = .init(fileName: "knownTickersIds", storage: storage, defaultValue: [:])
        super.init()
        CoinTickersFileStorage.migrateTickerIdsFrom_v1To_v2(config: config, storage: self)
        CoinTickersFileStorage.fixGnosisXdaiNativeTokenTicker(config: config, tickersStore: tickersStore)
    }

}

extension CoinTickersFileStorage {
    static func migrateTickerIdsFrom_v1To_v2(config: Config, storage: TickerIdsStorage) {
        guard !config.tickerIdsHasMigratedTo_v2 else { return }

        var config = config
        config.tickerIdsHasMigratedTo_v2 = true
        config.tickerIdsLastFetchedDate = nil
        storage.removeTickerIds()
    }

    //TODO remove after sometime once users no longer have this problem
    static func fixGnosisXdaiNativeTokenTicker(config: Config, tickersStore: Storage<[AssignedCoinTickerId: CoinTicker]>) {
        //Fix older code
        if tickersStore.value.contains(where: { k, v in k == "gnosis" && v.symbol == "gno" }) {
            tickersStore.removeAll()
        } else {
            //no-op
        }
    }
}

extension Config {
    static let migrationTo_v2Key = "migrationTo_v2Key"

    var tickerIdsHasMigratedTo_v2: Bool {
        get { return defaults.bool(forKey: Config.migrationTo_v2Key) }
        set { defaults.set(newValue, forKey: Config.migrationTo_v2Key) }
    }
}

extension CoinTickersFileStorage: CoinTickersStorage {

    public var tickersDidUpdate: AnyPublisher<Void, Never> {
        tickersStore.publisher
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    public func ticker(for key: AddressAndRPCServer) -> CoinTicker? {
        guard let tickerId = tickersStore.value.keys.first(where: { $0 == key }) else { return nil }
        return tickersStore.value[tickerId]
    }

    public func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker]) {
        for each in tickers {
            tickersStore.value[each.key] = each.value
        }
    }
}

extension CoinTickersFileStorage: ChartHistoryStorage {

    public func addOrUpdateChartHistory(history result: ChartHistory, period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId) {
        guard !result.prices.isEmpty else { return }
        var newHistory = historyStore.value[tickerId] ?? [:]
        newHistory[period] = .init(history: result, fetchDate: Date())
        historyStore.value[tickerId] = newHistory
    }

    public func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId) -> MappedChartHistory? {
        return historyStore.value[tickerId]?[period]
    }
}

extension CoinTickersFileStorage: TickerIdsStorage {

    public var updateTickerId: AnyPublisher<(tickerId: TickerIdString, key: AddressAndRPCServer), Never> {
        updateTickerIdSubject.eraseToAnyPublisher()
    }

    public var tickerIds: [TickerId] {
        return allTickersIdsStore.value
    }

    public func hasTickerIds() -> Bool {
        return !allTickersIdsStore.value.isEmpty
    }

    public func knownTickerId(for key: TokenMappedToTicker) -> TickerIdString? {
        let key = AddressAndRPCServer(address: key.contractAddress, server: key.server)
        return knownTickersIdsStore.value[key]
    }

    public func addOrUpdate(tickerId: TickerIdString?, for _key: TokenMappedToTicker) {
        let key = AddressAndRPCServer(address: _key.contractAddress, server: _key.server)

        if let id = tickerId, _key.coinGeckoId != id { updateTickerIdSubject.send((tickerId: id, key: key)) }

        guard knownTickersIdsStore.value[key] != tickerId else { return }

        knownTickersIdsStore.value[key] = tickerId
    }

    public func addOrUpdate(tickerIds: [TickerId]) {
        allTickersIdsStore.value = tickerIds
    }

    public func removeTickerIds() {
        allTickersIdsStore.removeAll()
    }
}
