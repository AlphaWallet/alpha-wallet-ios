// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

extension WalletConnectCoordinator {

    static func fake() -> WalletConnectCoordinator {
        let keystore = FakeEtherKeystore()
        var sessions = ServerDictionary<WalletSession>()
        let session = WalletSession.make()
        sessions[session.server] = session
        return .init(keystore: keystore, sessions: sessions, navigationController: .init(), analyticsCoordinator: FakeAnalyticsService(), config: .make(), nativeCryptoCurrencyPrices: .init())
    }
}

class ConfigTests: XCTestCase {

    //This is still used by Dapp browser
    func testChangeChainID() {
        let testDefaults = UserDefaults.test
        XCTAssertEqual(1, Config.getChainId(defaults: testDefaults))
        Config.setChainId(RPCServer.ropsten.chainID, defaults: testDefaults)
        XCTAssertEqual(RPCServer.ropsten.chainID, Config.getChainId(defaults: testDefaults))
    }

    func testSwitchLocale() {
        let assetDefinitionStore = AssetDefinitionStore()
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        let config: Config = .make()
        Config.setLocale(AppLocale.english)
        let tokenActionsService = FakeSwapTokenService()

        let coordinator_1 = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeKeystore(),
            config: config,
            tokenCollection: .init(filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService, coinTickersFetcher: FakeCoinTickersFetcher()), tokenDataStores: []),
            nativeCryptoCurrencyPrices: .init(),
            assetDefinitionStore: AssetDefinitionStore(),
            eventsDataStore: FakeEventsDataStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeKeystore(), wallet: .make(), config: config, analyticsCoordinator: FakeAnalyticsService()),
            filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService, coinTickersFetcher: FakeCoinTickersFetcher()),
            analyticsCoordinator: FakeAnalyticsService(),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            transactionsStorages: .init(),
            coinTickersFetcher: CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config),
            activitiesService: FakeActivitiesService(),
            walletBalanceCoordinator: FakeWalletBalanceCoordinator()
        )

        coordinator_1.start()
        coordinator_1.tokensViewController.viewWillAppear(false)
        XCTAssertEqual(coordinator_1.tokensViewController.title, "Wallet")

        Config.setLocale(AppLocale.simplifiedChinese)

        let coordinator_2 = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeKeystore(),
            config: config,
            tokenCollection: .init(filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService, coinTickersFetcher: FakeCoinTickersFetcher()), tokenDataStores: []),
            nativeCryptoCurrencyPrices: .init(),
            assetDefinitionStore: AssetDefinitionStore(),
            eventsDataStore: FakeEventsDataStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeKeystore(), wallet: .make(), config: config, analyticsCoordinator: FakeAnalyticsService()),
            filterTokensCoordinator: FilterTokensCoordinator(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService, coinTickersFetcher: FakeCoinTickersFetcher()),
            analyticsCoordinator: FakeAnalyticsService(),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            transactionsStorages: .init(),
            coinTickersFetcher: CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config),
            activitiesService: FakeActivitiesService(),
            walletBalanceCoordinator: FakeWalletBalanceCoordinator()
        )

        coordinator_2.start()
        coordinator_2.tokensViewController.viewWillAppear(false)
        XCTAssertEqual(coordinator_2.tokensViewController.title, "我的钱包")

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        Config.setLocale(AppLocale.system)
    }
}
