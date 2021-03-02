// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class InitialWalletCreationCoordinatorTests: XCTestCase {

    func testImportWallet() {
        let coordinator = InitialWalletCreationCoordinator(
            config: .make(),
            navigationController: FakeNavigationController(),
            keystore: FakeKeystore(),
            analyticsCoordinator: FakeAnalyticsService()
        )

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
    }
}
