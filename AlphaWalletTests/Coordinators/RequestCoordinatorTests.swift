// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class RequestCoordinatorTests: XCTestCase {
    func testRootViewController() {
        let coordinator = RequestCoordinator(navigationController: FakeNavigationController(), account: .make(), domainResolutionService: FakeDomainResolutionService())
        coordinator.start()
        XCTAssertTrue(coordinator.navigationController.viewControllers.first is RequestViewController)
    }
}
