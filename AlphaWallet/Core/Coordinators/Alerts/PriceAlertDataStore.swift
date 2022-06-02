//
//  PriceAlertDataStoreType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import Combine
import AlphaWalletCore

enum PriceAlertUpdates {
    case enabled(Bool)
    case value(value: Double, marketPrice: Double)
}

protocol PriceAlertDataStoreType: class {
    var alertsPublisher: AnyPublisher<[PriceAlert], Never> { get }
    var alerts: [PriceAlert] { get }

    func add(alert: PriceAlert)
    func update(alert: PriceAlert, update: PriceAlertUpdates)
    func update(indexPath: IndexPath, update: PriceAlertUpdates)
    func remove(indexPath: IndexPath)
}

class PriceAlertDataStore: PriceAlertDataStoreType {
    var alertsPublisher: AnyPublisher<[PriceAlert], Never> {
        return storage.publisher
    }

    var alerts: [PriceAlert] {
        storage.value
    }
    
    private enum Keys {
        static func alertsKey(wallet: Wallet) -> String {
            return "alerts-\(wallet.address.eip55String)"
        }
    }

    private let storage: Storage<[PriceAlert]>

    init(wallet: Wallet) {
        self.storage = .init(fileName: PriceAlertDataStore.Keys.alertsKey(wallet: wallet), defaultValue: [])
    }

    func add(alert: PriceAlert) {
        storage.value.append(alert)
    }

    func update(alert alertToSearch: PriceAlert, update: PriceAlertUpdates) {
        guard let index = storage.value.firstIndex(where: { $0 == alertToSearch }) else { return }
        var alert = storage.value[index]

        switch update {
        case .enabled(let isEnabled):
            alert.isEnabled = isEnabled
        case .value(let value, let marketPrice):
            alert.type = .init(value: value, marketPrice: marketPrice)
        }
        storage.value[index] = alert
    }

    func update(indexPath: IndexPath, update: PriceAlertUpdates) {
        guard var alert = storage.value[safe: indexPath.row] else { return }
        switch update {
        case .enabled(let isEnabled):
            alert.isEnabled = isEnabled
        case .value(let value, let marketPrice):
            alert.type = .init(value: value, marketPrice: marketPrice)
        }

        storage.value[indexPath.row] = alert
    }

    func remove(indexPath: IndexPath) {
        guard storage.value.indices.contains(indexPath.row) else { return }
        storage.value.remove(at: indexPath.row)
    }
}
