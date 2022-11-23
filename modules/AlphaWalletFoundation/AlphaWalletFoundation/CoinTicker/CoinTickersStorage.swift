//
//  CoinTickersFetcherCache.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.06.2021.
//

import Combine
import RealmSwift
import AlphaWalletCore
import CombineExt

public typealias TickerIdString = String

public protocol CoinTickersStorage {
    var tickersDidUpdate: AnyPublisher<Void, Never> { get }

    func historyLastUpdatedAt(for key: AddressAndRPCServer, currency: Currency) -> Date?
    func ticker(for key: AddressAndRPCServer, currency: Currency) -> CoinTicker?
    func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker])
}

public protocol ChartHistoryStorage {
    func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId, currency: Currency) -> MappedChartHistory?
    func addOrUpdateChartHistory(history: ChartHistory, period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId)
}

public protocol TickerIdsStorage {
    var updateTickerIds: AnyPublisher<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never> { get }

    func hasTickerIds() -> Bool
    func tickerId(for token: TokenMappedToTicker) -> TickerId?
    func knownTickerId(for key: TokenMappedToTicker) -> TickerIdString?
    func addOrUpdate(tickerId: TickerIdString?, for key: TokenMappedToTicker)
    func addOrUpdate(tickerIds: [TickerId])
    func removeTickerIds()
}

extension RealmStore: TickerIdsStorage {

    public var updateTickerIds: AnyPublisher<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never> {
        var publisher: AnyPublisher<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never>!
        performSync { realm in
            publisher = realm.objects(KnownTickerIdObject.self)
                .changesetPublisher
                .compactMap { changeset -> [AssignedCoinTickerId]? in
                    switch changeset {
                    case .error, .initial:
                        return nil
                    case .update(let values, let deletions, let insertions, let modifications):
                        let objects = insertions.map { values[$0] } + modifications.map { values[$0] }
                        return objects.map { AssignedCoinTickerId(tickerId: $0.tickerIdString, primaryToken: .init(address: $0.contractAddress, server: $0.server)) }
                    }
                }.map { $0.map { (tickerId: $0.tickerId, key: $0.primaryToken) } }
                .eraseToAnyPublisher()
        }

        return publisher
    }

    public func hasTickerIds() -> Bool {
        var hasTickerIds: Bool = false
        performSync { realm in
            hasTickerIds = !realm.objects(TickerIdObject.self).isEmpty
        }

        return hasTickerIds
    }

    public func knownTickerId(for key: TokenMappedToTicker) -> TickerIdString? {
        var tickerIdString: TickerIdString?
        performSync { realm in
            let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: key.contractAddress, server: key.server)
            tickerIdString = realm.object(ofType: KnownTickerIdObject.self, forPrimaryKey: primaryKey)?.tickerIdString
        }

        return tickerIdString
    }

    public func addOrUpdate(tickerId: TickerIdString?, for key: TokenMappedToTicker) {
        performSync { realm in
            let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: key.contractAddress, server: key.server)
            let storedTicker = realm.object(ofType: KnownTickerIdObject.self, forPrimaryKey: primaryKey)
            if let tickerId = tickerId, let storedTickerId = storedTicker?.tickerIdString, tickerId == storedTickerId { return }

            try? realm.safeWrite {
                if let tickerId = tickerId {
                    if let value = storedTicker {
                        value.tickerIdString = tickerId
                    } else {
                        let knownTickerId = KnownTickerIdObject(server: key.server, contractAddress: key.contractAddress, tickerIdString: tickerId)
                        realm.add(knownTickerId, update: .all)
                    }
                } else {
                    guard let _storedTicker = storedTicker else { return }
                    realm.delete(_storedTicker)
                }
            }
        }
    }

    public func tickerId(for token: TokenMappedToTicker) -> TickerId? {
        var tickerId: TickerId?
        performSync { realm in
            let filter = TickerIdFilter()
            tickerId = realm.objects(TickerIdObject.self)
                .filter { filter.filterMathesInPlatforms(token: token, tickerId: $0) }
                .first
                .flatMap { TickerId(tickerIdObject: $0) }
        }
        return tickerId
    }

    public func addOrUpdate(tickerIds: [TickerId]) {
        guard !tickerIds.isEmpty else { return }

        let tickerIdsToSave = tickerIds.map { TickerIdObject(tickerId: $0) }
        performSync { realm in
            try? realm.safeWrite {
                realm.add(tickerIdsToSave, update: .all)
            }
        }
    }

    public func removeTickerIds() {
        performSync { realm in
            try? realm.safeWrite {
                realm.delete(realm.objects(TickerIdObject.self))
            }
        }
    }
}

extension RealmStore: ChartHistoryStorage {

    public func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId, currency: Currency) -> MappedChartHistory? {
        var history: MappedChartHistory?
        performSync { realm in
            let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: tickerId.primaryToken.address, server: tickerId.primaryToken.server)
            history = realm.object(ofType: AssignedCoinTickerIdObject.self, forPrimaryKey: primaryKey).flatMap { $0.chartHistory?[period]?[currency] }
        }

        return history
    }

    private static func getOrCreateKnownTickerId(for tickerId: AssignedCoinTickerId, in realm: Realm) -> KnownTickerIdObject {
        let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: tickerId.primaryToken.address, server: tickerId.primaryToken.server)
        var knownTickerId: KnownTickerIdObject
        if let _knownTickerId = realm.object(ofType: KnownTickerIdObject.self, forPrimaryKey: primaryKey) {
            knownTickerId = _knownTickerId
        } else {
            let _knownTickerId = KnownTickerIdObject(key: tickerId)
            realm.add(_knownTickerId, update: .all)
            knownTickerId = _knownTickerId
        }
        return knownTickerId
    }

    public func addOrUpdateChartHistory(history: ChartHistory, period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId) {
        performSync { realm in
            try? realm.safeWrite {
                let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: tickerId.primaryToken.address, server: tickerId.primaryToken.server)
                let knownTickerId = Self.getOrCreateKnownTickerId(for: tickerId, in: realm)

                if let assignedCoinTicker = realm.object(ofType: AssignedCoinTickerIdObject.self, forPrimaryKey: primaryKey) {
                    var histories = assignedCoinTicker.chartHistory ?? [:]
                    var historyForPeriod = histories[period] ?? [:]
                    historyForPeriod[history.currency] = .init(history: history, fetchDate: Date())
                    histories[period] = historyForPeriod

                    assignedCoinTicker.chartHistory = histories
                } else {
                    var newHistories: [ChartHistoryPeriod: [Currency: MappedChartHistory]] = [:]
                    newHistories[period] = [history.currency: .init(history: history, fetchDate: Date())]

                    let assignedCoinTicker = AssignedCoinTickerIdObject(tickerId: knownTickerId, tickers: [], chartHistories: newHistories)
                    realm.add(assignedCoinTicker, update: .all)
                }
            }
        }
    }
}

extension RealmStore: CoinTickersStorage {

    public var tickersDidUpdate: AnyPublisher<Void, Never> {
        var publisher: AnyPublisher<Void, Never>!
        performSync { realm in
            publisher = realm.objects(AssignedCoinTickerIdObject.self)
                .changesetPublisher
                .mapToVoid()
                .eraseToAnyPublisher()
        }

        return publisher
    }

    public func historyLastUpdatedAt(for key: AddressAndRPCServer, currency: Currency) -> Date? {
        var updatedAt: Date?
        performSync { realm in
            let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: key.address, server: key.server)
            let obj = realm.object(ofType: AssignedCoinTickerIdObject.self, forPrimaryKey: primaryKey)
            let historiesToCurrencies = obj?.chartHistory?.map { $0.value } ?? []
            if let anyHistory = historiesToCurrencies.compactMap { $0[currency] }.first {
                updatedAt = anyHistory.fetchDate
            }
        }

        return updatedAt
    }

    public func ticker(for key: AddressAndRPCServer, currency: Currency) -> CoinTicker? {
        var ticker: CoinTicker?
        performSync { realm in
            let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: key.address, server: key.server)
            ticker = realm.object(ofType: AssignedCoinTickerIdObject.self, forPrimaryKey: primaryKey)
                .flatMap { $0.tickers.first(where: { $0.currency == currency.code }).flatMap { CoinTicker(coinTickerObject: $0) } }
        }

        return ticker
    }

    public func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker]) {
        guard !tickers.isEmpty else { return }

        performSync { realm in
            try? realm.safeWrite {
                for each in tickers {
                    let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: each.key.primaryToken.address, server: each.key.primaryToken.server)
                    let tickerId = Self.getOrCreateKnownTickerId(for: each.key, in: realm)

                    let ticker = CoinTickerObject(coinTicker: each.value)
                    realm.add(ticker, update: .all)

                    if let assignedCoinTicker = realm.object(ofType: AssignedCoinTickerIdObject.self, forPrimaryKey: primaryKey) {
                        var tickers = Array(assignedCoinTicker.tickers.filter { !$0.isEqual(ticker) })
                        tickers.append(ticker)

                        assignedCoinTicker.tickers.removeAll()
                        assignedCoinTicker.tickers.append(objectsIn: tickers)
                    } else {
                        let assignedCoinTicker = AssignedCoinTickerIdObject(tickerId: tickerId, tickers: [ticker], chartHistories: nil)
                        realm.add(assignedCoinTicker, update: .all)
                    }
                }
            }
        }
    }
}
