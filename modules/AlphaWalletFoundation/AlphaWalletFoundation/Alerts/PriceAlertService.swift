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

public protocol PriceAlertServiceType: class {
    func alertsPublisher(forStrategy strategy: PriceAlertsFilterStrategy) -> AnyPublisher<[PriceAlert], Never>
    func alerts(forStrategy strategy: PriceAlertsFilterStrategy) -> [PriceAlert]
    func start()
    func add(alert: PriceAlert)
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
                return alerts.filter { $0.addressAndRPCServer == token.addressAndRPCServer }
            case .all:
                return alerts
            }
        }.eraseToAnyPublisher()
    }

    public func alerts(forStrategy strategy: PriceAlertsFilterStrategy) -> [PriceAlert] {
        switch strategy {
        case .token(let token):
            return datastore.alerts.filter { $0.addressAndRPCServer == token.addressAndRPCServer }
        case .all:
            return datastore.alerts
        }
    }

    public func add(alert: PriceAlert) {
        datastore.add(alert: alert)
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
