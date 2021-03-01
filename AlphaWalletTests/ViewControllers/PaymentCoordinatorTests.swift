// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class PaymentCoordinatorTests: XCTestCase {

    func testSendFlow() {
        let address: AlphaWallet.Address = .make()
        let coordinator = PaymentCoordinator(
            navigationController: FakeNavigationController(),
            flow: .send(type: .nativeCryptocurrency(TokenObject(), destination: .init(address: address), amount: nil)),
            session: .make(),
            keystore: FakeKeystore(),
            storage: FakeTokensDataStore(),
            ethPrice: Subscribable<Double>(nil),
            assetDefinitionStore: AssetDefinitionStore(),
            analyticsCoordinator: FakeAnalyticsService()
        )
        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is SendCoordinator)
    }

    func testRequestFlow() {
        let coordinator = PaymentCoordinator(
            navigationController: FakeNavigationController(),
            flow: .request,
            session: .make(),
            keystore: FakeKeystore(),
            storage: FakeTokensDataStore(),
            ethPrice: Subscribable<Double>(nil),
            assetDefinitionStore: AssetDefinitionStore(),
            analyticsCoordinator: FakeAnalyticsService()
        )

        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is RequestCoordinator)
    }
}
