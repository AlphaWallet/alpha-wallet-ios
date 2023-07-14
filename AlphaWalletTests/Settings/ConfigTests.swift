// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import AlphaWalletCore
import AlphaWalletFoundation

extension WalletConnectCoordinator {

    static func fake() -> WalletConnectCoordinator {
        let keystore = FakeEtherKeystore(wallets: [.make()])
        let dependencies = AtomicDictionary<Wallet, WalletDependencies>(value: [
            .make(): WalletDataProcessingPipeline.make(wallet: .make(), server: .main)
        ])

        let provider = WalletConnectProvider(keystore: keystore, config: .make(), dependencies: dependencies)

        return WalletConnectCoordinator(
            navigationController: .init(),
            analytics: FakeAnalyticsService(),
            walletConnectProvider: provider,
            restartHandler: RestartQueueHandler(),
            serversProvider: BaseServersProvider())
    }
}

class ConfigTests: XCTestCase {

        //This is still used by Dapp browser
    func testChangeChainID() {
        let testDefaults = UserDefaults.test
        XCTAssertEqual(1, Config.getChainId(defaults: testDefaults))
        Config.setChainId(RPCServer.goerli.chainID, defaults: testDefaults)
        XCTAssertEqual(RPCServer.goerli.chainID, Config.getChainId(defaults: testDefaults))
    }

    func testTokensNavigationTitle() {
        let sessionsProvider = FakeSessionsProvider.make(servers: [.main])

        let config: Config = .make()
        let tokenActionsService = FakeSwapTokenService()
        let dep1 = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)

        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessionsProvider: sessionsProvider,
            keystore: FakeEtherKeystore(),
            config: config,
            assetDefinitionStore: .make(),
            promptBackupCoordinator: .make(),
            analytics: FakeAnalyticsService(),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            coinTickersProvider: CoinTickers.make(),
            activitiesService: FakeActivitiesService(),
            walletBalanceService: FakeMultiWalletBalanceService(),
            tokenCollection: dep1.pipeline,
            tokensService: dep1.tokensService,
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokensFilter: .make(),
            currencyService: .make(),
            tokenImageFetcher: FakeTokenImageFetcher(),
            serversProvider: BaseServersProvider())

        coordinator.start()
        coordinator.tokensViewController.viewWillAppear(false)

        XCTAssertEqual(coordinator.tokensViewController.navigationItem.title, "0x1000…0000")
    }

    func testTabBarItemTitle() {
        Config.setLocale(AppLocale.english)
        let app1 = Application(
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        let coordinator_1 = AppCoordinator(
            window: .init(),
            navigationController: FakeNavigationController(),
            application: app1)

        coordinator_1.start()

        XCTAssertNotNil(coordinator_1.activeWalletCoordinator)
        XCTAssertEqual(coordinator_1.activeWalletCoordinator?.tokensCoordinator?.tokensViewController.tabBarItem.title, "Wallet")

        Config.setLocale(AppLocale.simplifiedChinese)

        let app2 = Application(
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        let coordinator_2 = AppCoordinator(
            window: .init(),
            navigationController: FakeNavigationController(),
            application: app2)

        coordinator_2.start()

        XCTAssertNotNil(coordinator_2.activeWalletCoordinator)
        XCTAssertEqual(coordinator_2.activeWalletCoordinator?.tokensCoordinator?.tokensViewController.tabBarItem.title, "我的钱包")

        //Must change this back to system, otherwise other tests will break either immediately or the next run
        Config.setLocale(AppLocale.system)
    }

    func testMakeSureDevelopmentFlagsAreAllFalse() {
        let mirror = Mirror(reflecting: Config.Development())
        for child in mirror.children {
            if let value = child.value as? Bool {
                XCTAssertFalse(value, "Property: \(String(describing: child.label)) should be `false`")
            } else {
                XCTFail("Property: \(String(describing: child.label)) should be `bool`")
            }
        }
    }
}
