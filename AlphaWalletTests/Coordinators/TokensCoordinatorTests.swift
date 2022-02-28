// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class FakeSwapTokenService: TokenActionsServiceType {
    func register(service: TokenActionsProvider) {

    }

    func service(ofType: TokenActionsProvider.Type) -> TokenActionsProvider? {
        return nil
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
        let tokenActionsService = FakeSwapTokenService()
        let tokensDataStore = FakeTokensDataStore()
        var transactionsStorages = ServerDictionary<TransactionsStorage>()
        transactionsStorages[.main] = FakeTransactionsStorage()

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
            transactionsStorages: transactionsStorages,
            coinTickersFetcher: CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config),
            activitiesService: FakeActivitiesService(),
            walletBalanceCoordinator: FakeWalletBalanceCoordinator()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}
