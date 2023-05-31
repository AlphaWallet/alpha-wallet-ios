// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class SendCoordinatorTests: XCTestCase {
    func testRootViewController() {
        let dep = WalletDataProcessingPipeline.make()
        let coordinator = SendCoordinator(
            transactionType: .nativeCryptocurrency(Token(), destination: .none, amount: .notSet),
            navigationController: FakeNavigationController(),
            session: .make(),
            sessionsProvider: FakeSessionsProvider.make(servers: [.main]),
            keystore: FakeEtherKeystore(),
            tokensPipeline: dep.pipeline,
            assetDefinitionStore: .make(),
            analytics: FakeAnalyticsService(),
            domainResolutionService: FakeDomainResolutionService(),
            networkService: FakeNetworkService(),
            tokenImageFetcher: FakeTokenImageFetcher(),
            tokensService: dep.tokensService)

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

    func testDestination() {
        let address: AlphaWallet.Address = .make()
        let dep = WalletDataProcessingPipeline.make()
        let coordinator = SendCoordinator(
            transactionType: .nativeCryptocurrency(Token(), destination: .init(address: address), amount: .notSet),
            navigationController: FakeNavigationController(),
            session: .make(),
            sessionsProvider: FakeSessionsProvider.make(servers: [.main]),
            keystore: FakeEtherKeystore(),
            tokensPipeline: dep.pipeline,
            assetDefinitionStore: .make(),
            analytics: FakeAnalyticsService(),
            domainResolutionService: FakeDomainResolutionService(),
            networkService: FakeNetworkService(),
            tokenImageFetcher: FakeTokenImageFetcher(),
            tokensService: dep.tokensService)
        coordinator.start()

        XCTAssertEqual(address.eip55String, coordinator.sendViewController.targetAddressTextField.value)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

}
