// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class RequestCoordinatorTests: XCTestCase {
    func testRootViewController() {
        let coordinator = RequestCoordinator(navigationController: FakeNavigationController(), account: .make(), domainResolutionService: FakeDomainResolutionService())
        coordinator.start()
        XCTAssertTrue(coordinator.navigationController.viewControllers.first is RequestViewController)
    }
}

