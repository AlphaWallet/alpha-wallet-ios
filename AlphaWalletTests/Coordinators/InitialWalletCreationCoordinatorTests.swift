// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class InitialWalletCreationCoordinatorTests: XCTestCase {

    func testImportWallet() {
        let coordinator = InitialWalletCreationCoordinator(
            config: .make(),
            navigationController: FakeNavigationController(),
            keystore: FakeKeystore(),
            entryPoint: .importWallet,
            analyticsCoordinator: nil
        )

        coordinator.start()

        XCTAssertTrue((coordinator.navigationController.presentedViewController as? UINavigationController)?.viewControllers[0] is ImportWalletViewController)
    }
}
