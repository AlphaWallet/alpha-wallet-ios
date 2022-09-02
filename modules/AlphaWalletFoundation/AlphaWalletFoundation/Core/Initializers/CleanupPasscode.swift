//
//  CleanupPasscode.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.06.2022.
//

import Foundation

public final class CleanupPasscode: Initializer {
    private let lock = Lock()
    private let keystore: Keystore

    public init(keystore: Keystore) {
        self.keystore = keystore
    }

    public func perform() {
        //We should clean passcode if there is no wallets. This step is required for app reinstall.
        if !keystore.hasWallets {
            lock.clear()
        }
    }
}
