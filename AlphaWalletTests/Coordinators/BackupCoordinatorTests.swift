// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class BackupCoordinatorTests: XCTestCase {
    func testStartWithHdWallet() {
        let coordinator = BackupCoordinator(
            navigationController: FakeNavigationController(),
            keystore: FakeEtherKeystore(wallets: [.init(address: .make(), origin: .mnemonic)]),
            account: .make(),
            analyticsCoordinator: FakeAnalyticsService()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SeedPhraseBackupIntroductionViewController)
    }

    func testStartWithKeystoreWallet() {
        let coordinator = BackupCoordinator(
                navigationController: FakeNavigationController(),
                keystore: FakeEtherKeystore(wallets: [.init(address: .make(), origin: .privateKey)]),
                account: .make(),
                analyticsCoordinator: FakeAnalyticsService()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is KeystoreBackupIntroductionViewController)
    }
}
