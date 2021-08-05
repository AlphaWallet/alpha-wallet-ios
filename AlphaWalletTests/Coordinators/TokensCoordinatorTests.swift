// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class FakeSwapTokenService: TokenActionsServiceType {
    func register(service: TokenActionsProvider) {

    }

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        false
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        []
    }
}

class TokensCoordinatorTests: XCTestCase {
    func testRootViewController() {
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        let config: Config = .make()
        let assetDefinitionStore = AssetDefinitionStore()
        let tokenActionsService = FakeSwapTokenService()
        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeKeystore(),
            config: config,
            tokenCollection: .init(filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService), tokenDataStores: []),
            nativeCryptoCurrencyPrices: .init(),
            assetDefinitionStore: AssetDefinitionStore(),
            eventsDataStore: FakeEventsDataStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeKeystore(), wallet: .make(), config: config, analyticsCoordinator: FakeAnalyticsService()),
            filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService),
            analyticsCoordinator: FakeAnalyticsService(),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            transactionsStorages: .init(),
            coinTickersFetcher: CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config),
            activitiesService: FakeActivitiesService(),
            walletBalanceCoordinator: FakeWalletBalanceCoordinator()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}