// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
@testable import AlphaWallet
import AlphaWalletFoundation
import AlphaWalletHardwareWallet

final class FakeEtherKeystore: EtherKeystore {
    convenience init(wallets: [Wallet] = [], recentlyUsedWallet: Wallet? = nil) {
        let walletAddressesStore = fakeWalletAddressStore(wallets: wallets, recentlyUsedWallet: recentlyUsedWallet)
        self.init(keychain: KeychainStorage.make(), walletAddressesStore: walletAddressesStore, analytics: FakeAnalyticsService(), legacyFileBasedKeystore: .make(), hardwareWalletFactory: FakeHardwareWalletCreator())
        self.recentlyUsedWallet = recentlyUsedWallet
    }

    convenience init(walletAddressesStore: WalletAddressesStore) {
        self.init(keychain: KeychainStorage.make(), walletAddressesStore: walletAddressesStore, analytics: FakeAnalyticsService(), legacyFileBasedKeystore: .make(), hardwareWalletFactory: FakeHardwareWalletCreator())
        self.recentlyUsedWallet = recentlyUsedWallet
    }
}

extension LegacyFileBasedKeystore {
    static func make() -> LegacyFileBasedKeystore {
        (try! LegacyFileBasedKeystore(securedStorage: KeychainStorage.make()))
    }
}

fileprivate class FakeHardwareWallet: HardwareWallet {
    func signHash(_ hash: Data) async throws -> Data {
        //no-op
        return Data()
    }

    func getAddress() async throws -> AlphaWallet.Address {
        //no-op
        return Constants.nullAddress
    }
}

fileprivate class FakeHardwareWalletCreator: HardwareWalletFactory {
    func createWallet() -> HardwareWallet {
        return FakeHardwareWallet()
    }
}