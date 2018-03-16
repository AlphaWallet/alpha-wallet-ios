// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import Trust

class LockCreatePasscodeCoordinatorTest: XCTestCase {
    func testStart() {
        let navigationController = UINavigationController()
        let coordinator = AlphaWalletLockCreatePasscodeCoordinator(navigationController: navigationController, model: LockCreatePasscodeViewModel())
        coordinator.start()
        XCTAssertTrue(navigationController.viewControllers.first is AlphaWalletLockCreatePasscodeViewController)
    }
    func testStop() {
        let navigationController = UINavigationController()
        let coordinator = AlphaWalletLockCreatePasscodeCoordinator(navigationController: navigationController, model: LockCreatePasscodeViewModel())
        coordinator.start()
        XCTAssertTrue(navigationController.viewControllers.first is AlphaWalletLockCreatePasscodeViewController)
        coordinator.stop()
        XCTAssertNil(navigationController.presentedViewController)
    }
}
