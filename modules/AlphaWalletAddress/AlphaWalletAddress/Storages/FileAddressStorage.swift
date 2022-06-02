//
//  FileAddressStorage.swift
//  AlphaWalletAddress
//
//  Created by Vladyslav Shepitko on 02.06.2022.
//

import Foundation
import UIKit
import AlphaWalletCore

public class FileAddressStorage: AddressStorage {
    private var lastCount: Int
    private var persistentStorage: StorageType
    private let inMemoryStorage: InMemoryAddressStorage
    private let fileName: String
    private let dropToPersistentStorageThreshold: Int = 1000

    public subscript(key: AddressKey) -> AlphaWallet.Address? {
        get { inMemoryStorage[key] }
        set { addOrUpdate(address: newValue, for: key) }
    }

    public var cachedAddressCount: Int { return inMemoryStorage.count }
    public var persistantAddressCount: Int { return lastCount }

    public init(fileName: String = "addresses", persistentStorage: StorageType = FileStorage(fileExtension: "json")) {
        self.fileName = fileName
        self.persistentStorage = persistentStorage

        let snapshot: [String: AlphaWallet.Address] = persistentStorage.load(forKey: fileName, defaultValue: [:])
        inMemoryStorage = .init(values: snapshot)
        lastCount = snapshot.count
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            self.persist(self.inMemoryStorage.allValues)
        }
    }

    private func addOrUpdate(address: AlphaWallet.Address?, for key: String) {
        inMemoryStorage[key] = address

        if inMemoryStorage.count - lastCount > dropToPersistentStorageThreshold {
            persist(inMemoryStorage.allValues)
            lastCount = inMemoryStorage.count
        }
    }

    private func persist(_ values: [String: AlphaWallet.Address]) {
        guard let data = try? JSONEncoder().encode(values) else { return }

        persistentStorage.setData(data, forKey: fileName)
    }
}
