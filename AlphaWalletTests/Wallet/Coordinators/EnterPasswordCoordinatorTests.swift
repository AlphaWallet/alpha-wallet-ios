// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class EnterPasswordCoordinatorTests: XCTestCase {
    
    func testStart() {
        let coordinator = EnterPasswordCoordinator(account: .make())

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is KeystoreBackupIntroductionViewController)
    }
}
