//
//  PriceAlertServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import Foundation
import Combine

public enum PriceAlertsFilterStrategy {
    case all
    case token(Token)
}

public protocol PriceAlertServiceType: AnyObject {
    func alertsPublisher(forStrategy strategy: PriceAlertsFilterStrategy) -> AnyPublisher<[PriceAlert], Never>
    func alerts(forStrategy strategy: PriceAlertsFilterStrategy) -> [PriceAlert]
    func start()
    func add(alert: PriceAlert) -> Bool
    func update(alert: PriceAlert, update: PriceAlertUpdates)
    func update(indexPath: IndexPath, update: PriceAlertUpdates)
    func remove(indexPath: IndexPath)
}

public class PriceAlertService: PriceAlertServiceType {
    private let datastore: PriceAlertDataStoreType
    private var timer: Timer?
    private let wallet: Wallet

    public init(datastore: PriceAlertDataStoreType, wallet: Wallet) {
        self.wallet = wallet
        self.datastore = datastore
    }

    public func start() {
        //no-op
    }

    public func alertsPublisher(forStrategy strategy: PriceAlertsFilterStrategy) -> AnyPublisher<[PriceAlert], Never> {
        datastore.alertsPublisher.map { alerts -> [PriceAlert] in
            switch strategy {
            case .token(let token):
                return alerts.filter { $0.addressAndRPCServer == token.addressAndRPCServer }.uniqued()
            case .all:
                return alerts.uniqued()
            }
        }.eraseToAnyPublisher()
    }

    public func alerts(forStrategy strategy: PriceAlertsFilterStrategy) -> [PriceAlert] {
        switch strategy {
        case .token(let token):
            return datastore.alerts.filter { $0.addressAndRPCServer == token.addressAndRPCServer }.uniqued()
        case .all:
            return datastore.alerts.uniqued()
        }
    }

    public func add(alert: PriceAlert) -> Bool {
        guard !datastore.alerts.contains(where: { $0 == alert }) else { return false }

        datastore.add(alert: alert)
        return true
    }

    public func update(alert: PriceAlert, update: PriceAlertUpdates) {
        datastore.update(alert: alert, update: update)
    }

    public func update(indexPath: IndexPath, update: PriceAlertUpdates) {
        datastore.update(indexPath: indexPath, update: update)
    }

    public func remove(indexPath: IndexPath) {
        datastore.remove(indexPath: indexPath)
    }
}

extension Sequence where Element: Hashable {
    public func uniqued() -> [Element] {
        var elements: [Element] = []
        for value in self where !elements.contains(value) {
            elements.append(value)
        }
        return elements
    }
}
