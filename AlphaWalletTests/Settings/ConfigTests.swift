// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import AlphaWalletFoundation

extension WalletConnectCoordinator {

    static func fake() -> WalletConnectCoordinator {
        let keystore = FakeEtherKeystore(wallets: [.make()])
        let dependencies = AtomicDictionary<Wallet, AppCoordinator.WalletDependencies>(value: [
            .make(): WalletDataProcessingPipeline.make(wallet: .make(), server: .main)
        ])

        let provider = WalletConnectProvider(keystore: keystore, config: .make(), dependencies: dependencies)

        return WalletConnectCoordinator(
            keystore: keystore,
            navigationController: .init(),
            analytics: FakeAnalyticsService(),
            domainResolutionService: FakeDomainResolutionService(),
            config: .make(),
            assetDefinitionStore: .make(),
            networkService: FakeNetworkService(),
            walletConnectProvider: provider,
            dependencies: dependencies,
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
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
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

        let coordinator_1 = AppCoordinator(
            window: .init(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

        coordinator_1.start()

        XCTAssertNotNil(coordinator_1.activeWalletCoordinator)
        XCTAssertEqual(coordinator_1.activeWalletCoordinator?.tokensCoordinator?.tokensViewController.tabBarItem.title, "Wallet")

        Config.setLocale(AppLocale.simplifiedChinese)

        let coordinator_2 = AppCoordinator(
            window: .init(),
            analytics: FakeAnalyticsService(),
            keystore: FakeEtherKeystore(
                wallets: [.make()],
                recentlyUsedWallet: .make()
            ),
            navigationController: FakeNavigationController(),
            securedStorage: KeychainStorage.make(),
            legacyFileBasedKeystore: .make())

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
