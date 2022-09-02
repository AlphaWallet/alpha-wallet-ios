// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class LockEnterPasscodeCoordinatorTest: XCTestCase {
    func testStart() {
        let fakeLock = FakeLock()
        let coordinator = LockEnterPasscodeCoordinator(lock: fakeLock)
        XCTAssertTrue(coordinator.window.isHidden)
        coordinator.start()
        XCTAssertFalse(coordinator.window.isHidden)
        coordinator.stop()
    }
    func testStop() {
        let fakeLock = FakeLock()
        let coordinator = LockEnterPasscodeCoordinator(lock: fakeLock)
        coordinator.start()
        XCTAssertFalse(coordinator.window.isHidden)
        coordinator.stop()
        XCTAssertTrue(coordinator.window.isHidden)
    }
    func testDisableLock() {
        let fakeLock = FakeLock()
        fakeLock.passcodeSet = false 
        let coordinator = LockEnterPasscodeCoordinator(lock: fakeLock)
        XCTAssertTrue(coordinator.window.isHidden)
        coordinator.start()
        XCTAssertTrue(coordinator.window.isHidden)
        coordinator.stop()
    }
}
