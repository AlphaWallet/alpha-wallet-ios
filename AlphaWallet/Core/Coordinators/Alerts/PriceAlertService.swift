//
//  PriceAlertServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import Combine

enum PriceAlertsFilterStrategy {
    case all
    case token(Token)
}

protocol PriceAlertServiceType: class {
    func alertsPublisher(forStrategy strategy: PriceAlertsFilterStrategy) -> AnyPublisher<[PriceAlert], Never>
    func alerts(forStrategy strategy: PriceAlertsFilterStrategy) -> [PriceAlert]
    func start()
    func add(alert: PriceAlert)
    func update(alert: PriceAlert, update: PriceAlertUpdates)
    func update(indexPath: IndexPath, update: PriceAlertUpdates)
    func remove(indexPath: IndexPath)
}

class PriceAlertService: PriceAlertServiceType {
    private let datastore: PriceAlertDataStoreType
    private var timer: Timer?
    private let wallet: Wallet

    init(datastore: PriceAlertDataStoreType, wallet: Wallet) {
        self.wallet = wallet
        self.datastore = datastore
    }

    func start() {
        //no-op
    }

    func alertsPublisher(forStrategy strategy: PriceAlertsFilterStrategy) -> AnyPublisher<[PriceAlert], Never> {
        datastore.alertsPublisher.map { alerts -> [PriceAlert] in
            switch strategy {
            case .token(let token):
                return alerts.filter { $0.addressAndRPCServer == token.addressAndRPCServer }
            case .all:
                return alerts
            }
        }.eraseToAnyPublisher()
    }

    func alerts(forStrategy strategy: PriceAlertsFilterStrategy) -> [PriceAlert] {
        switch strategy {
        case .token(let token):
            return datastore.alerts.filter { $0.addressAndRPCServer == token.addressAndRPCServer }
        case .all:
            return datastore.alerts
        }
    }

    func add(alert: PriceAlert) {
        datastore.add(alert: alert)
    }

    func update(alert: PriceAlert, update: PriceAlertUpdates) {
        datastore.update(alert: alert, update: update)
    }

    func update(indexPath: IndexPath, update: PriceAlertUpdates) {
        datastore.update(indexPath: indexPath, update: update)
    }

    func remove(indexPath: IndexPath) {
        datastore.remove(indexPath: indexPath)
    }
}
