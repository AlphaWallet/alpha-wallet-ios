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

    func ticker(for key: AddressAndRPCServer, currency: Currency) async -> CoinTicker?
    @discardableResult func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker]) -> Task<Void, Never>
}

public protocol ChartHistoryStorage {
    func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId, currency: Currency) async -> MappedChartHistory?
    func addOrUpdateChartHistory(history: ChartHistory, period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId)
}

public protocol TickerIdsStorage {
    var updateTickerIds: AnyPublisher<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never> { get }

    func hasTickerIds() async -> Bool
    func tickerId(for token: TokenMappedToTicker) async -> TickerId?
    func knownTickerId(for key: TokenMappedToTicker) async -> TickerIdString?
    func addOrUpdate(tickerId: TickerIdString?, for key: TokenMappedToTicker)
    func addOrUpdate(tickerIds: [TickerId])
    func removeTickerIds()
}

extension RealmStore: TickerIdsStorage {

    public var updateTickerIds: AnyPublisher<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never> {
        let publisher = PassthroughSubject<[(tickerId: TickerIdString, key: AddressAndRPCServer)], Never>()
        Task {
            await performSync { realm in
                realm.objects(KnownTickerIdObject.self)
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
                        .sink { value in
                            publisher.send(value)
                        }.store(in: &self.cancellables)
            }
        }
        return publisher.eraseToAnyPublisher()
    }

    public func hasTickerIds() async -> Bool {
        var hasTickerIds: Bool = false
        await perform { realm in
            hasTickerIds = !realm.objects(TickerIdObject.self).isEmpty
        }

        return hasTickerIds
    }

    public func knownTickerId(for key: TokenMappedToTicker) async -> TickerIdString? {
        var tickerIdString: TickerIdString?
        await perform { realm in
            let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: key.contractAddress, server: key.server)
            tickerIdString = realm.object(ofType: KnownTickerIdObject.self, forPrimaryKey: primaryKey)?.tickerIdString
        }

        return tickerIdString
    }

    public func addOrUpdate(tickerId: TickerIdString?, for key: TokenMappedToTicker) {
        Task {
            await perform { realm in
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
    }

    public func tickerId(for token: TokenMappedToTicker) async -> TickerId? {
        var tickerId: TickerId?
        await perform { realm in
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
        Task {
            await perform { realm in
                try? realm.safeWrite {
                    realm.add(tickerIdsToSave, update: .all)
                }
            }
        }
    }

    public func removeTickerIds() {
        Task {
            await perform { realm in
                try? realm.safeWrite {
                    realm.delete(realm.objects(TickerIdObject.self))
                }
            }
        }
    }
}

extension RealmStore: ChartHistoryStorage {

    public func chartHistory(period: ChartHistoryPeriod, for tickerId: AssignedCoinTickerId, currency: Currency) async -> MappedChartHistory? {
        var history: MappedChartHistory?
        await perform { realm in
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
        Task {
            await perform { realm in
                try? realm.safeWrite {
                    let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: tickerId.primaryToken.address, server: tickerId.primaryToken.server)
                    let knownTickerId = Self.getOrCreateKnownTickerId(for: tickerId, in: realm)

                    if let assignedCoinTicker = realm.object(ofType: AssignedCoinTickerIdObject.self, forPrimaryKey: primaryKey) {
                        var histories = assignedCoinTicker.chartHistory ?? [:]
                        var historyForPeriod = histories[period, default: [:]]
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
}

extension RealmStore: CoinTickersStorage {
    public var tickersDidUpdate: AnyPublisher<Void, Never> {
        let publisher = PassthroughSubject<Void, Never>()
        Task {
            await performSync { realm in
                realm.objects(AssignedCoinTickerIdObject.self)
                        .changesetPublisher
                        .mapToVoid()
                        .sink { value in
                            publisher.send(value)
                        }.store(in: &self.cancellables)
            }
        }
        Task {
            await performSync { realm in
                realm.objects(CoinTickerObject.self)
                        .changesetPublisher
                        .mapToVoid()
                        .sink { value in
                            publisher.send(value)
                        }.store(in: &self.cancellables)
            }
        }
        return publisher.eraseToAnyPublisher()
    }

    public func ticker(for key: AddressAndRPCServer, currency: Currency) async -> CoinTicker? {
        var ticker: CoinTicker?
        await perform { realm in
            let primaryKey = ContractAddressObject.generatePrimaryKey(fromContract: key.address, server: key.server)
            ticker = realm.object(ofType: AssignedCoinTickerIdObject.self, forPrimaryKey: primaryKey)
                .flatMap { $0.tickers.first(where: { $0.currency == currency.code }).flatMap { CoinTicker(coinTickerObject: $0) } }
        }

        return ticker
    }

    public func addOrUpdate(tickers: [AssignedCoinTickerId: CoinTicker]) -> Task<Void, Never> {
        guard !tickers.isEmpty else { return Task {} }

        return Task {
            await perform { realm in
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
}
