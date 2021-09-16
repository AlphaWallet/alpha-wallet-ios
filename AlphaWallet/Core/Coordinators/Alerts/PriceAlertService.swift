//
//  PriceAlertServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import PromiseKit

enum PriceAlertsFilterStrategy {
    case all
    case token(TokenObject)
}

protocol PriceAlertServiceType: class {
    func alertsSubscribable(strategy: PriceAlertsFilterStrategy) -> Subscribable<[PriceAlert]>
    func start()
    func add(alert: PriceAlert) -> Promise<Void>
    func update(alert: PriceAlert, update: PriceAlertUpdates) -> Promise<Void>
    func update(indexPath: IndexPath, update: PriceAlertUpdates) -> Promise<Void>
    func remove(indexPath: IndexPath) -> Promise<Void>
}

class PriceAlertService: PriceAlertServiceType {
    func alertsSubscribable(strategy: PriceAlertsFilterStrategy) -> Subscribable<[PriceAlert]> {
        datastore.alertsSubscribable.map { alerts -> [PriceAlert] in
            switch strategy {
            case .token(let token):
                return alerts.filter { $0.addressAndRPCServer == token.addressAndRPCServer }
            case .all:
                return alerts
            }
        }
    }

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

    func add(alert: PriceAlert) -> Promise<Void> {
        datastore.add(alert: alert)
    }

    func update(alert: PriceAlert, update: PriceAlertUpdates) -> Promise<Void> {
        datastore.update(alert: alert, update: update)
    }

    func update(indexPath: IndexPath, update: PriceAlertUpdates) -> Promise<Void> {
        datastore.update(indexPath: indexPath, update: update)
    }

    func remove(indexPath: IndexPath) -> Promise<Void> {
        datastore.remove(indexPath: indexPath)
    }
}

extension PriceAlertService {
    class functional {}
}

extension PriceAlertService.functional {
    static func notifyUserAlertReceived(for alert: PriceAlert, in wallet: Wallet) {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.body = alert.description
        content.sound = .default

        let identifier = Constants.alertReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier)-\(wallet.address.eip55String)-\(alert.addressAndRPCServer.description)", content: content, trigger: nil)

        DispatchQueue.main.async {
            notificationCenter.add(request)
        }
    }
}

