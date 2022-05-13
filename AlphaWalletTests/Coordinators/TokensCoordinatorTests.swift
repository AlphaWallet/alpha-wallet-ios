// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine

final class FakeSwapTokenService: TokenActionsService {
}

class TokensCoordinatorTests: XCTestCase {

    func testRootViewController() {
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        let config: Config = .make()
        let tokenActionsService = FakeSwapTokenService()
        let tokensDataStore = FakeTokensDataStore()

        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeKeystore(),
            config: config,
            tokensDataStore: tokensDataStore,
            assetDefinitionStore: AssetDefinitionStore(),
            eventsDataStore: FakeEventsDataStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeKeystore(), wallet: .make(), config: config, analyticsCoordinator: FakeAnalyticsService()),
            analyticsCoordinator: FakeAnalyticsService(),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            coinTickersFetcher: CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config),
            activitiesService: FakeActivitiesService(),
            walletBalanceService: FakeMultiWalletBalanceService()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}
