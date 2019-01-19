// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import TrustKeystore

class SendCoordinatorTests: XCTestCase {
    
    func testRootViewController() {
        let coordinator = SendCoordinator(
            transferType: .nativeCryptocurrency(config: Config(), destination: .none),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            storage: FakeTokensDataStore(),
            account: .make(),
            ethPrice: Subscribable<Double>(nil)
        )

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

    func testDestination() {
        let address: Address = .make()
        let coordinator = SendCoordinator(
            transferType: .nativeCryptocurrency(config: Config(), destination: address),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            storage: FakeTokensDataStore(),
            account: .make(),
            ethPrice: Subscribable<Double>(nil)
        )
        coordinator.start()

        XCTAssertEqual(address.description, coordinator.sendViewController.targetAddressTextField.value)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

}
