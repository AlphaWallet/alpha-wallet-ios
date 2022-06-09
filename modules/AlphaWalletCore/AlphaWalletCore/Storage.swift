//
//  Storage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.11.2021.
//

import Foundation
import Combine
import AlphaWalletCore

public class Storage<T: Codable> {
    private let fileName: String
    private let valueSubject: CurrentValueSubject<T, Never>
    private let storage: StorageType
    private let defaultValue: T

    public var publisher: AnyPublisher<T, Never> {
        valueSubject.eraseToAnyPublisher()
    }

    public var value: T {
        get {
            return valueSubject.value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                storage.deleteEntry(forKey: fileName)
                valueSubject.value = defaultValue
                return
            }

            storage.setData(data, forKey: fileName)
            valueSubject.value = newValue
        }
    }

    public init(fileName: String, storage: StorageType = FileStorage(), defaultValue: T) {
        self.defaultValue = defaultValue
        self.fileName = fileName
        self.storage = storage

        valueSubject = .init(storage.load(forKey: fileName, defaultValue: defaultValue))
    }
}
