// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import Trust
import TrustKeystore

class SendCoordinatorTests: XCTestCase {
    
    func testRootViewController() {
        let coordinator = SendCoordinator(
            transferType: .ether(destination: .none),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            storage: FakeTokensDataStore(),
            account: .make()
        )

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

    func testDestination() {
        let address: Address = .make()
        let coordinator = SendCoordinator(
            transferType: .ether(destination: address),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            storage: FakeTokensDataStore(),
            account: .make()
        )
        coordinator.start()

        XCTAssertEqual(address.description, coordinator.sendViewController.addressRow?.value)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

}
