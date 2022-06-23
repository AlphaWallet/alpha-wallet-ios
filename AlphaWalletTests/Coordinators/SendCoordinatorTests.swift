// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class SendCoordinatorTests: XCTestCase {

    func testRootViewController() {
        let coordinator = SendCoordinator(
            transactionType: .nativeCryptocurrency(TokenObject(), destination: .none, amount: nil),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            tokensDataStore: FakeTokensDataStore(),
            assetDefinitionStore: AssetDefinitionStore(),
            analyticsCoordinator: FakeAnalyticsService(),
            domainResolutionService: FakeDomainResolutionService()
        )

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

    func testDestination() {
        let address: AlphaWallet.Address = .make()
        let coordinator = SendCoordinator(
            transactionType: .nativeCryptocurrency(TokenObject(), destination: .init(address: address), amount: nil),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            tokensDataStore: FakeTokensDataStore(),
            assetDefinitionStore: AssetDefinitionStore(),
            analyticsCoordinator: FakeAnalyticsService(),
            domainResolutionService: FakeDomainResolutionService()
        )
        coordinator.start()

        XCTAssertEqual(address.eip55String, coordinator.sendViewController.targetAddressTextField.value)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

}
