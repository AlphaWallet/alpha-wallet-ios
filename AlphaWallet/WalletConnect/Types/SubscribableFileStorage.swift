//
//  SubscribableFileStorage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.11.2021.
//

import Foundation

class SubscribableFileStorage<T: Codable> {
    lazy var valueSubscribable: Subscribable<T> = .init(storage.load(forKey: fileName, defaultValue: defaultValue))
    private let fileName: String

    var value: T {
        get {
            if let value = valueSubscribable.value {
                return value
            } else {
                let value: T = storage.load(forKey: fileName, defaultValue: defaultValue)
                valueSubscribable.value = value

                return value
            }
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                storage.deleteEntry(forKey: fileName)
                valueSubscribable.value = defaultValue
                return
            }

            storage.setData(data, forKey: fileName)
            valueSubscribable.value = newValue
        }
    }

    private let storage: StorageType
    private let defaultValue: T

    init(fileName: String, storage: StorageType = FileStorage(), defaultValue: T) {
        self.defaultValue = defaultValue
        self.fileName = fileName
        self.storage = storage
    }
}
