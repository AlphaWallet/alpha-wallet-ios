// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class WalletCoordinatorTests: XCTestCase {

    func testImportWallet() {
        let coordinator = WalletCoordinator(
            config: .make(),
            navigationController: FakeNavigationController(),
            keystore: FakeKeystore(),
            analyticsCoordinator: FakeAnalyticsService()
        )

        coordinator.start(.importWallet)

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is ImportWalletViewController)
    }

    func testCreateInstantWallet() {
        let delegate = FakeWalletCoordinatorDelegate()
        let coordinator = WalletCoordinator(
            config: .make(),
            navigationController: FakeNavigationController(),
            keystore: FakeEtherKeystore(),
            analyticsCoordinator: FakeAnalyticsService()
        )
        coordinator.delegate = delegate

        XCTAssertFalse(coordinator.start(.createInstantWallet))
    }

    func testPushImportWallet() {
        let coordinator = WalletCoordinator(
            config: .make(),
            navigationController: FakeNavigationController(),
            keystore: FakeKeystore(),
            analyticsCoordinator: FakeAnalyticsService()
        )

        coordinator.start(.addInitialWallet)

        coordinator.pushImportWallet()

        XCTAssertTrue(coordinator.navigationController.viewControllers[1] is ImportWalletViewController)
    }
}

class FakeWalletCoordinatorDelegate: WalletCoordinatorDelegate {
    var didFail: Error? = .none
    var didFinishAccount: Wallet? = .none
    var didCancel: Bool = false

    func didCancel(in coordinator: WalletCoordinator) {
        didCancel = true
    }

    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        didFinishAccount = account
    }

    func didFail(with error: Error, in coordinator: WalletCoordinator) {
        didFail = error
    }
}
