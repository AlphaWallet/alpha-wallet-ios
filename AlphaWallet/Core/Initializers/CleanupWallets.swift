//
//  CleanupWallets.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import Foundation

final class CleanupWallets: Initializer {
    private let keystore: Keystore

    init(keystore: Keystore) {
        self.keystore = keystore
    }

    func perform() {
        if isRunningTests() {
            try! RealmConfiguration.removeWalletsFolderForTests()
            JsonWalletAddressesStore.removeWalletsFolderForTests()
        } else {
            //no-op
        }

        DatabaseMigration.removeWalletsIfRealmFilesMissed(keystore: keystore)
    }
}
