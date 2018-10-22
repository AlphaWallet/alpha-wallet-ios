// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class InitialWalletCreationCoordinatorTests: XCTestCase {

    func testImportWallet() {
        let coordinator = InitialWalletCreationCoordinator(
            navigationController: FakeNavigationController(),
            keystore: FakeKeystore(),
            entryPoint: .importWallet
        )

        coordinator.start()

        XCTAssertTrue((coordinator.navigationController.presentedViewController as? UINavigationController)?.viewControllers[0] is ImportWalletViewController)
    }
}
