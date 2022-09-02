// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import AlphaWalletFoundation

extension WalletConnectCoordinator {

    static func fake() -> WalletConnectCoordinator {
        let keystore = FakeEtherKeystore()
        let sessionProvider: SessionsProvider = .make(wallet: .make(), servers: [.main])
        return WalletConnectCoordinator(keystore: keystore, navigationController: .init(), analytics: FakeAnalyticsService(), domainResolutionService: FakeDomainResolutionService(), config: .make(), sessionProvider: sessionProvider, assetDefinitionStore: AssetDefinitionStore())
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
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()

        let config: Config = .make()
        Config.setLocale(AppLocale.english)
        let tokenActionsService = FakeSwapTokenService()
        let dep1 = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)

        let coordinator_1 = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeEtherKeystore(),
            config: config,
            assetDefinitionStore: AssetDefinitionStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeEtherKeystore(), wallet: .make(), config: config, analytics: FakeAnalyticsService()),
            analytics: FakeAnalyticsService(),
            openSea: OpenSea(analytics: FakeAnalyticsService(), queue: .global()),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            coinTickersFetcher: CoinGeckoTickersFetcher.make(),
            activitiesService: FakeActivitiesService(),
            walletBalanceService: FakeMultiWalletBalanceService(),
            tokenCollection: dep1.pipeline,
            importToken: dep1.importToken,
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokensFilter: .make()
        )

        coordinator_1.start()
        coordinator_1.tokensViewController.viewWillAppear(false)
        XCTAssertEqual(coordinator_1.tokensViewController.title, "Wallet")

        Config.setLocale(AppLocale.simplifiedChinese)

        let dep2 = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)
        let coordinator_2 = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeEtherKeystore(),
            config: config,
            assetDefinitionStore: AssetDefinitionStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeEtherKeystore(), wallet: .make(), config: config, analytics: FakeAnalyticsService()),
            analytics: FakeAnalyticsService(),
            openSea: OpenSea(analytics: FakeAnalyticsService(), queue: .global()),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            coinTickersFetcher: CoinGeckoTickersFetcher.make(),
            activitiesService: FakeActivitiesService(),
            walletBalanceService: FakeMultiWalletBalanceService(),
            tokenCollection: dep2.pipeline,
            importToken: dep2.importToken,
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokensFilter: .make()
        )

        coordinator_2.start()
        coordinator_2.tokensViewController.viewWillAppear(false)
        XCTAssertEqual(coordinator_2.tokensViewController.title, "我的钱包")

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
