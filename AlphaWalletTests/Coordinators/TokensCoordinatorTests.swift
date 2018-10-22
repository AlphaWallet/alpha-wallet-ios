// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class TokensCoordinatorTests: XCTestCase {
    
    func testRootViewController() {
        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            tokensStorage: FakeTokensDataStore(),
            assetDefinitionStore: AssetDefinitionStore()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}
