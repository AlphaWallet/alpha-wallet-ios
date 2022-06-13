// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine

func sessions(server: RPCServer = .main) -> CurrentValueSubject<ServerDictionary<WalletSession>, Never> {
    return CurrentValueSubject<ServerDictionary<WalletSession>, Never>(.make(server: server))
}

class PaymentCoordinatorTests: XCTestCase {

    func testSendFlow() {
        let address: AlphaWallet.Address = .make()
        let coordinator = PaymentCoordinator(
            navigationController: FakeNavigationController(),
            flow: .send(type: .transaction(.nativeCryptocurrency(TokenObject(), destination: .init(address: address), amount: nil))),
            server: .main,
            sessions: sessions(server: .main),
            keystore: FakeKeystore(),
            tokensDataStore: FakeTokensDataStore(),
            assetDefinitionStore: AssetDefinitionStore(),
            analyticsCoordinator: FakeAnalyticsService(),
            eventsDataStore: FakeEventsDataStore(),
            tokenCollection: MultipleChainsTokenCollection.fake(),
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: FakeTokenSwapper()
        )
        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is SendCoordinator)
    }

    func testRequestFlow() {
        let coordinator = PaymentCoordinator(
            navigationController: FakeNavigationController(),
            flow: .request,
            server: .main,
            sessions: sessions(server: .main),
            keystore: FakeKeystore(),
            tokensDataStore: FakeTokensDataStore(),
            assetDefinitionStore: AssetDefinitionStore(),
            analyticsCoordinator: FakeAnalyticsService(),
            eventsDataStore: FakeEventsDataStore(),
            tokenCollection: MultipleChainsTokenCollection.fake(),
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: FakeTokenSwapper()
        )

        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is RequestCoordinator)
    }
}
