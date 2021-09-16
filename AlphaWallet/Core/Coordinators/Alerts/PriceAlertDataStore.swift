//
//  PriceAlertDataStoreType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import PromiseKit

enum PriceAlertUpdates {
    case enabled(Bool)
    case value(value: Double, marketPrice: Double)
}

protocol PriceAlertDataStoreType: class {
    var alertsSubscribable: Subscribable<[PriceAlert]> { get }

    func add(alert: PriceAlert) -> Promise<Void>
    func update(alert: PriceAlert, update: PriceAlertUpdates) -> Promise<Void>
    func update(indexPath: IndexPath, update: PriceAlertUpdates) -> Promise<Void>
    func remove(indexPath: IndexPath) -> Promise<Void>
}

class PriceAlertDataStore: PriceAlertDataStoreType {
    lazy var alertsSubscribable: Subscribable<[PriceAlert]> = .init(load(forKey: key, defaultValue: []))
    private let storage: StorageType
    private enum Keys {
        static func alertsKey(wallet: Wallet) -> String {
            return "alerts-\(wallet.address.eip55String)"
        }
    }

    private var alerts: [PriceAlert] {
        get {
            if let value = alertsSubscribable.value {
                return value
            } else {
                let value: [PriceAlert] = load(forKey: key, defaultValue: [])
                alertsSubscribable.value = value

                return value
            }
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }

            _ = storage.setData(data, forKey: key)
            alertsSubscribable.value = newValue
        }
    }
    private let key: String

    init(storage: StorageType = FileStorage(), wallet: Wallet) {
        self.storage = storage
        self.key = PriceAlertDataStore.Keys.alertsKey(wallet: wallet)
    }

    private func load<T: Codable>(forKey key: String, defaultValue: T) -> T {
        guard let data = storage.data(forKey: key) else {
            return defaultValue
        }

        guard let result = try? JSONDecoder().decode(T.self, from: data) else {
            //NOTE: in case if decoding error appears, remove existed file
            _ = storage.deleteEntry(forKey: key)

            return defaultValue
        }

        return result
    }

    func add(alert: PriceAlert) -> Promise<Void> {
        return Promise { seal in
            alerts.append(alert)

            seal.fulfill(())
        }
    }

    func update(alert alertToSearch: PriceAlert, update: PriceAlertUpdates) -> Promise<Void> {
        return Promise { seal in
            if let index = alerts.firstIndex(where: { $0 == alertToSearch }) {
                var alert = alerts[index]

                switch update {
                case .enabled(let isEnabled):
                    alert.isEnabled = isEnabled
                case .value(let value, let marketPrice):
                    alert.type = .init(value: value, marketPrice: marketPrice)
                }
                alerts[index] = alert

                seal.fulfill(())
            } else {
                seal.reject(PMKError.cancelled)
            }
        }
    }

    func update(indexPath: IndexPath, update: PriceAlertUpdates) -> Promise<Void> {
        return Promise { seal in
            if var alert = alerts[safe: indexPath.row] {
                switch update {
                case .enabled(let isEnabled):
                    alert.isEnabled = isEnabled
                case .value(let value, let marketPrice):
                    alert.type = .init(value: value, marketPrice: marketPrice)
                }

                alerts[indexPath.row] = alert

                seal.fulfill(())
            } else {
                seal.reject(PMKError.cancelled)
            }
        }
    }

    func remove(indexPath: IndexPath) -> Promise<Void> {
        return Promise { seal in
            guard alerts.indices.contains(indexPath.row) else { return seal.reject(PMKError.cancelled) }
            alerts.remove(at: indexPath.row)

            seal.fulfill(())
        }
    }
}
