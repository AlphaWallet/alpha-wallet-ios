//
//  WalletConnectV1Storage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.01.2023.
//

import Foundation
import AlphaWalletCore
import Combine

class WalletConnectV1Storage {
    enum Keys {
        static let storageFileKey = "walletConnectSessions-v1"
    }
    private let storage: Storage<[WalletConnectV1Session]> = .init(fileName: Keys.storageFileKey, defaultValue: [])

    var publisher: AnyPublisher<[WalletConnectV1Session], Never> {
        storage.publisher
    }

    var value: [WalletConnectV1Session] {
        get { return storage.value }
        set { storage.value = newValue }
    }
}
