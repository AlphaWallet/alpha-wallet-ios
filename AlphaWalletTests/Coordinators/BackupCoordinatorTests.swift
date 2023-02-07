// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

extension PromptBackup {
    static func make(walletBalanceProvidable: WalletBalanceProvidable = MultiWalletBalanceService(currencyService: .make())) -> PromptBackup {
        return PromptBackup(
            keystore: FakeEtherKeystore(wallets: [.make(origin: .hd)]),
            config: .make(),
            analytics: FakeAnalyticsService(),
            walletBalanceProvidable: walletBalanceProvidable,
            filename: "fake-prompt-backup.json")
    }
}

class BackupCoordinatorTests: XCTestCase {
    func testStartWithHdWallet() {
        let coordinator = BackupCoordinator(
            navigationController: FakeNavigationController(),
            keystore: FakeEtherKeystore(wallets: [.make(origin: .hd)]),
            account: .make(origin: .hd),
            analytics: FakeAnalyticsService(),
            promptBackup: .make())
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SeedPhraseBackupIntroductionViewController)
    }

    func testStartWithKeystoreWallet() {
        let coordinator = BackupCoordinator(
                navigationController: FakeNavigationController(),
                keystore: FakeEtherKeystore(wallets: [.make(origin: .privateKey)]),
                account: .make(origin: .privateKey),
                analytics: FakeAnalyticsService(),
                promptBackup: .make())
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is KeystoreBackupIntroductionViewController)
    }
}
