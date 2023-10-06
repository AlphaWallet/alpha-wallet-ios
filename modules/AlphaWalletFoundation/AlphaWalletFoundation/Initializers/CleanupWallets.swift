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

        //Didn't merge with the if-else above because it would seem like they are alternatives. They aren't
        if !isRunningTests() {
            //Don't do this when running tests because they will delete the test wallets that we have just set up (and not had the chance to use yet)
            DatabaseMigration.removeWalletsIfRealmFilesMissed(keystore: keystore)
        }
        DatabaseMigration.oneTimeMigrationForBookmarksAndUrlHistoryToSharedRealm(keystore: keystore, config: config)
    }
}
