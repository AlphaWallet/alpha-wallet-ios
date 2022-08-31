// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class BackupCoordinatorTests: XCTestCase {
    func testStartWithHdWallet() {
        let coordinator = BackupCoordinator(
            navigationController: FakeNavigationController(),
            keystore: FakeEtherKeystore(wallets: [.make(origin: .hd)]),
            account: .make(origin: .hd),
            analytics: FakeAnalyticsService()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SeedPhraseBackupIntroductionViewController)
    }

    func testStartWithKeystoreWallet() {
        let coordinator = BackupCoordinator(
                navigationController: FakeNavigationController(),
                keystore: FakeEtherKeystore(wallets: [.make(origin: .privateKey)]),
                account: .make(origin: .privateKey),
                analytics: FakeAnalyticsService()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is KeystoreBackupIntroductionViewController)
    }
}
