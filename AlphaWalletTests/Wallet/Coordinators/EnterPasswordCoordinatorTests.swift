// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class EnterPasswordCoordinatorTests: XCTestCase {

    func testStart() {
        let coordinator = EnterPasswordCoordinator(account: .make())

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is KeystoreBackupIntroductionViewController)
    }
}
