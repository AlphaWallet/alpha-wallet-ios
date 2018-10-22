// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import SafariServices

class DepositCoordinatorTests: XCTestCase {
    private var didCallOpenWebPage = false
    
    func testStart() {
        let coordinator = DepositCoordinator(
            navigationController: FakeNavigationController(),
            account: .make(),
            delegate: nil
        )

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.presentedViewController is UIAlertController)
    }

    func testDepositCoinbase() {
        let coordinator = DepositCoordinator(
            navigationController: FakeNavigationController(),
            account: .make(),
            delegate: self
        )

        coordinator.showCoinbase()
        XCTAssertTrue(didCallOpenWebPage)
    }

    func testDepositShapeShift() {
        let coordinator = DepositCoordinator(
            navigationController: FakeNavigationController(),
            account: .make(),
            delegate: self
        )

        coordinator.showShapeShift()
        XCTAssertTrue(didCallOpenWebPage)
    }
}

extension DepositCoordinatorTests: DepositCoordinatorDelegate {
}

extension DepositCoordinatorTests: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        didCallOpenWebPage = true
    }
}
