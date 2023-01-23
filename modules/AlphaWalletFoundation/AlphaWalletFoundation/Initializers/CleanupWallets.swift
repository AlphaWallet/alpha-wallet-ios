//
//  CleanupWallets.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import Foundation

public final class CleanupWallets: Initializer {
    private let keystore: Keystore
    private let config: Config
    
    public init(keystore: Keystore, config: Config) {
        self.keystore = keystore
        self.config = config
    }

    public func perform() {
        if isRunningTests() {
            try! RealmConfiguration.removeWalletsFolderForTests()
            JsonWalletAddressesStore.removeWalletsFolderForTests()
        } else {
            //no-op
        }

        DatabaseMigration.removeWalletsIfRealmFilesMissed(keystore: keystore)
        DatabaseMigration.oneTimeMigrationForBookmarksAndUrlHistoryToSharedRealm(keystore: keystore, config: config)
    }
}
