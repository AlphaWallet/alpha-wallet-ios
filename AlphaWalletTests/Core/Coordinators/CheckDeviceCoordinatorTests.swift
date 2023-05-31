// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class CheckDeviceCoordinatorTests: XCTestCase {
    func testStartPositive() {
        let navigationController = FakeNavigationController()

        let coordinator = CheckDeviceCoordinator(
            navigationController: navigationController,
            jailbreakChecker: FakeJailbreakChecker(jailbroken: true)
        )

        coordinator.start()

        XCTAssertTrue(navigationController.presentedViewController is UIAlertController)
    }

    func testStartNegative() {
        let navigationController = FakeNavigationController()

        let coordinator = CheckDeviceCoordinator(
            navigationController: navigationController,
            jailbreakChecker: FakeJailbreakChecker(jailbroken: false)
        )

        coordinator.start()

        XCTAssertFalse(navigationController.presentedViewController is UIAlertController)
    }
}
