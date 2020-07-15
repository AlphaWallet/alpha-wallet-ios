// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class RequestCoordinatorTests: XCTestCase {

    func testRootViewController() {
        let coordinator = RequestCoordinator(
            navigationController: FakeNavigationController(),
            account: .make(),
            server: .main
        )

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers.first is RequestViewController)
    }
}

