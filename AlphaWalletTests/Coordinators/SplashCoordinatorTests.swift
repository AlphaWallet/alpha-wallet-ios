// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import XCTest

class SplashCoordinatorTests: XCTestCase {
    func testStart() {
        let window = UIWindow()
        let coordinator = SplashCoordinator(window: window)
        coordinator.start()
        XCTAssertFalse(window.isHidden)
    }
    func testStop() {
        let window = UIWindow()
        let coordinator = SplashCoordinator(window: window)
        coordinator.start()
        coordinator.stop()
        XCTAssertTrue(window.isHidden)
    }
}
