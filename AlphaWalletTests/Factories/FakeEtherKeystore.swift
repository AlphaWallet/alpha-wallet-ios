// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import KeychainSwift

final class FakeEtherKeystore: EtherKeystore {
    convenience init(wallets: [Wallet] = [], recentlyUsedWallet: Wallet? = nil) {
        let uniqueString = NSUUID().uuidString
        let walletAddressesStore = fakeWalletAddressStore(wallets: wallets, recentlyUsedWallet: recentlyUsedWallet)

        try! self.init(keychain: KeychainSwift(keyPrefix: "fake" + uniqueString), walletAddressesStore: walletAddressesStore, analytics: FakeAnalyticsService())
        self.recentlyUsedWallet = recentlyUsedWallet
    }

    convenience init(walletAddressesStore: WalletAddressesStore) {
        let uniqueString = NSUUID().uuidString
        try! self.init(keychain: KeychainSwift(keyPrefix: "fake" + uniqueString), walletAddressesStore: walletAddressesStore, analytics: FakeAnalyticsService())
        self.recentlyUsedWallet = recentlyUsedWallet
    }
}
