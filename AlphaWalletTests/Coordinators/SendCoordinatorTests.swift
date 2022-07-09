// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class SendCoordinatorTests: XCTestCase {

    func testRootViewController() {
        let coordinator = SendCoordinator(
            transactionType: .nativeCryptocurrency(Token(), destination: .none, amount: nil),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            service: FakeTokensService(),
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
            transactionType: .nativeCryptocurrency(Token(), destination: .init(address: address), amount: nil),
            navigationController: FakeNavigationController(),
            session: .make(),
            keystore: FakeKeystore(),
            service: FakeTokensService(),
            assetDefinitionStore: AssetDefinitionStore(),
            analyticsCoordinator: FakeAnalyticsService(),
            domainResolutionService: FakeDomainResolutionService()
        )
        coordinator.start()

        XCTAssertEqual(address.eip55String, coordinator.sendViewController.targetAddressTextField.value)
        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is SendViewController)
    }

}

class FakeTokensService: TokenAddable, TokenProvidable {
    private let dataStore: TokensDataStore

    init(dataStore: TokensDataStore = FakeTokensDataStore()) {
        self.dataStore = dataStore
    }

    func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token] {
        dataStore.addCustom(tokens: tokens, shouldUpdateBalance: shouldUpdateBalance)
    }

    func token(for contract: AlphaWallet.Address) -> Token? {
        dataStore.token(forContract: contract)
    }

    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token? {
        dataStore.token(forContract: contract, server: server)
    }

}
