//
//  CoinTickersFetcherCache.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import Combine
import AlphaWalletCore

typealias TickerIdString = String

protocol CoinTickersStorage {
    var tickersDidUpdate: AnyPublisher<Void, Never> { get }

    func ticker(for addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
    func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker])
}

protocol ChartHistoryStorage {
    func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId) -> MappedChartHistory?
    func addOrUpdateChartHistory(history: ChartHistory, period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId)
}

protocol TickerIdsStorage {
    var tickerIds: [TickerId] { get }
    var updateTickerId: AnyPublisher<(tickerId: TickerIdString, key: AddressAndRPCServer), Never> { get }

    func hasTickerIds() -> Bool
    func knownTickerId(for key: TokenMappedToTicker) -> TickerIdString?
    func addOrUpdate(tickerId: TickerIdString?, for key: TokenMappedToTicker)
    func addOrUpdate(tickerIds: [TickerId])
    func removeTickerIds()
}

class CoinTickersFileStorage: NSObject {
    private let historyStore: Storage<[AssignedCoinTickerId: [ChartHistoryPeriod: MappedChartHistory]]>
    private let tickersStore: Storage<[AssignedCoinTickerId: CoinTicker]>
    private let allTickersIdsStore: Storage<[TickerId]>
    private let knownTickersIdsStore: Storage<[AddressAndRPCServer: TickerIdString]>
    private let updateTickerIdSubject: PassthroughSubject<(tickerId: TickerIdString, key: AddressAndRPCServer), Never> = .init()

    init(config: Config, storage: StorageType) {
        historyStore = .init(fileName: "history", storage: storage, defaultValue: [:])
        allTickersIdsStore = .init(fileName: "tickersIds", storage: storage, defaultValue: [])
        tickersStore = .init(fileName: "tickers", storage: storage, defaultValue: [:])
        knownTickersIdsStore = .init(fileName: "knownTickersIds", storage: storage, defaultValue: [:])
        super.init()
        CoinTickersFileStorage.migrateTickerIdsFrom_v1To_v2(config: config, storage: self)
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
}

extension Config {
    static let migrationTo_v2Key = "migrationTo_v2Key"

    var tickerIdsHasMigratedTo_v2: Bool {
        get { return defaults.bool(forKey: Config.migrationTo_v2Key) }
        set { defaults.set(newValue, forKey: Config.migrationTo_v2Key) }
    }
}

extension CoinTickersFileStorage: CoinTickersStorage {

    var tickersDidUpdate: AnyPublisher<Void, Never> {
        tickersStore.publisher
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    func ticker(for key: AddressAndRPCServer) -> CoinTicker? {
        guard let tickerId = tickersStore.value.keys.first(where: { $0 == key }) else { return nil }
        return tickersStore.value[tickerId]
    }

    func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker]) {
        for each in tickers {
            tickersStore.value[each.key] = each.value
        }
    }
}

extension CoinTickersFileStorage: ChartHistoryStorage {

    func addOrUpdateChartHistory(history result: ChartHistory, period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId) {
        guard !result.prices.isEmpty else { return }
        var newHistory = historyStore.value[tickerId] ?? [:]
        newHistory[period] = .init(history: result, fetchDate: Date())
        historyStore.value[tickerId] = newHistory
    }

    func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId) -> MappedChartHistory? {
        return historyStore.value[tickerId]?[period]
    } 
}

extension CoinTickersFileStorage: TickerIdsStorage {

    var updateTickerId: AnyPublisher<(tickerId: TickerIdString, key: AddressAndRPCServer), Never> {
        updateTickerIdSubject.eraseToAnyPublisher()
    }

    var tickerIds: [TickerId] {
        return allTickersIdsStore.value
    }

    func hasTickerIds() -> Bool {
        return !allTickersIdsStore.value.isEmpty
    }

    func knownTickerId(for key: TokenMappedToTicker) -> TickerIdString? {
        let key = AddressAndRPCServer(address: key.contractAddress, server: key.server)
        return knownTickersIdsStore.value[key]
    }

    func addOrUpdate(tickerId: TickerIdString?, for _key: TokenMappedToTicker) {
        let key = AddressAndRPCServer(address: _key.contractAddress, server: _key.server)

        if let id = tickerId, _key.coinGeckoId != id { updateTickerIdSubject.send((tickerId: id, key: key)) }

        guard knownTickersIdsStore.value[key] != tickerId else { return }

        knownTickersIdsStore.value[key] = tickerId
    }

    func addOrUpdate(tickerIds: [TickerId]) {
        allTickersIdsStore.value = tickerIds
    }

    func removeTickerIds() {
        allTickersIdsStore.removeAll()
    }
}
