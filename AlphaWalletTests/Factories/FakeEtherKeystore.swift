// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import KeychainSwift

struct FakeWallet {
    let address: AlphaWallet.Address
    let origin: WalletOrigin
}

extension FakeWallet {
    init(wallet: Wallet) {
        address = wallet.address
        switch wallet.type {
        case .real:
            origin = .mnemonic
        case .watch:
            origin = .watch
        }
    }
}

class FakeEtherKeystore: EtherKeystore {
    convenience init(wallets: [FakeWallet] = [], recentlyUsedWallet: Wallet? = nil) {
        let uniqueString = NSUUID().uuidString
        let walletAddressesStore = fakeWalletAddressStore(wallets: wallets, recentlyUsedWallet: recentlyUsedWallet)

        try! self.init(keychain: KeychainSwift(keyPrefix: "fake" + uniqueString), walletAddressesStore: walletAddressesStore, analyticsCoordinator: FakeAnalyticsService())
        self.recentlyUsedWallet = recentlyUsedWallet
    }

    convenience init(walletAddressesStore: WalletAddressesStore) {
        let uniqueString = NSUUID().uuidString
        try! self.init(keychain: KeychainSwift(keyPrefix: "fake" + uniqueString), walletAddressesStore: walletAddressesStore, analyticsCoordinator: FakeAnalyticsService())
        self.recentlyUsedWallet = recentlyUsedWallet
    }
}
