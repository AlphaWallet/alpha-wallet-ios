// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class BackupCoordinatorTests: XCTestCase {
    func testStartWithHdWallet() {
        let coordinator = BackupCoordinator(
            navigationController: FakeNavigationController(),
            keystore: FakeKeystore(assumeAllWalletsType: .hdWallet),
            account: .make()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is ShowSeedPhraseViewController)
    }

    func testStartWithKeystoreWallet() {
        let coordinator = BackupCoordinator(
                navigationController: FakeNavigationController(),
                keystore: FakeKeystore(assumeAllWalletsType: .keyStoreWallet),
                account: .make()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is KeystoreBackupIntroductionViewController)
    }
}
