// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class FakeSwapTokenService: SwapTokenServiceType {
    func register(service: SwapTokenActionsService) {

    }

    func isSupport(token: TokenObject) -> Bool {
        false
    }

    func actions(token: TokenObject) -> [TokenInstanceAction] {
        []
    }
}

class TokensCoordinatorTests: XCTestCase {
    func testRootViewController() {
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        let config: Config = .make()
        let assetDefinitionStore = AssetDefinitionStore()
        let swapTokenService = FakeSwapTokenService()
        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeKeystore(),
            config: config,
            tokenCollection: .init(filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, swapTokenService: swapTokenService), tokenDataStores: []),
            nativeCryptoCurrencyPrices: .init(),
            assetDefinitionStore: AssetDefinitionStore(),
            eventsDataStore: FakeEventsDataStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeKeystore(), wallet: .make(), config: config, analyticsCoordinator: FakeAnalyticsService()),
            filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, swapTokenService: swapTokenService),
            analyticsCoordinator: FakeAnalyticsService(),
            swapTokenService: swapTokenService,
            walletConnectCoordinator: .fake()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}
