// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class InitialWalletCreationCoordinatorTests: XCTestCase {
    func testImportWallet() {
        let coordinator = InitialWalletCreationCoordinator(
            config: .make(),
            navigationController: FakeNavigationController(),
            keystore: FakeEtherKeystore(),
            analytics: FakeAnalyticsService(),
            domainResolutionService: FakeDomainResolutionService()
        )

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is CreateInitialWalletViewController)
    }
}
