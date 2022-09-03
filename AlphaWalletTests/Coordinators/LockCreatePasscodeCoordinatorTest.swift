// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class LockCreatePasscodeCoordinatorTest: XCTestCase {
    func testStart() {
        let navigationController = NavigationController()
        let coordinator = LockCreatePasscodeCoordinator(navigationController: navigationController, lock: FakeLock())
        coordinator.start()
        XCTAssertTrue(navigationController.viewControllers.first is LockCreatePasscodeViewController)
    }
    func testStop() {
        let navigationController = NavigationController()
        let coordinator = LockCreatePasscodeCoordinator(navigationController: navigationController, lock: FakeLock())
        coordinator.start()
        XCTAssertTrue(navigationController.viewControllers.first is LockCreatePasscodeViewController)
        coordinator.stop()
        XCTAssertNil(navigationController.presentedViewController)
    }
}
