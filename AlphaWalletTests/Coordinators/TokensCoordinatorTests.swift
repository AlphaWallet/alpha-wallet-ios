// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class TokensCoordinatorTests: XCTestCase {
    
    func testRootViewController() {
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeKeystore(),
            tokenCollection: .init(tokenDataStores: []),
            nativeCryptoCurrencyPrices: .init(),
            assetDefinitionStore: AssetDefinitionStore()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}
