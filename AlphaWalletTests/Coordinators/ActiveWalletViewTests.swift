// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation
import Combine
import AlphaWalletCore
import PromiseKit

final class FakeNetworkService: NetworkService {

    var response: Swift.Result<URLRequest.Response, AlphaWalletFoundation.SessionTaskError>?
    var callbackQueue: DispatchQueue = .main
    var delay: TimeInterval = 0.5
    private (set) var calls: Int = 0

    func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                usingThreshold: UInt64,
                with request: AlphaWalletFoundation.URLRequestConvertible,
                callbackQueue: DispatchQueue = .main) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
        return .empty()
    }

    func dataTaskPublisher(_ request: AlphaWalletFoundation.URLRequestConvertible, callbackQueue: DispatchQueue = .main) -> AnyPublisher<URLRequest.Response, SessionTaskError> {
        return AnyPublisher<URLRequest.Response, AlphaWalletFoundation.SessionTaskError>.create { [callbackQueue, delay] seal in
            self.calls += 1

            callbackQueue.asyncAfter(deadline: .now() + delay) {
                switch self.response {
                case .success(let value):
                    seal.send(value)
                    seal.send(completion: .finished)
                case .failure(let error):
                    seal.send(completion: .failure(error))
                case .none:
                    seal.send(completion: .finished)
                }
            }

            return AnyCancellable {

            }
        }.eraseToAnyPublisher()
    }

    func dataTaskPromise(_ request: AlphaWalletFoundation.URLRequestConvertible, callbackQueue: DispatchQueue = .main) -> Promise<URLRequest.Response> {
        PromiseKit.Promise<URLRequest.Response>.init { [callbackQueue, delay] seal in
            callbackQueue.asyncAfter(deadline: .now() + delay) {
                switch self.response {
                case .success(let value):
                    seal.fulfill(value)
                case .failure(let error):
                    seal.reject(error)
                case .none:
                    seal.reject(PMKError.cancelled)
                }
            }
        }
    }
}

extension AnyCAIP10AccountProvidable {
    static func make(wallets: [Wallet] = [.make()], servers: [RPCServer] = [.main]) -> AnyCAIP10AccountProvidable {
        let keystore = FakeEtherKeystore(wallets: wallets)
        let serversProvidable = BaseServersProvider(config: .make(enabledServers: servers))
        return AnyCAIP10AccountProvidable(keystore: keystore, serversProvidable: serversProvidable)
    }
}

extension AssetDefinitionStore {
    static func make() -> AssetDefinitionStore {
        return .init(networkService: FakeNetworkService(), blockchainsProvider: BlockchainsProvider.make(servers: [.main]))
    }
}

// swiftlint:disable type_body_length
class ActiveWalletViewTests: XCTestCase {

    private let currencyService = CurrencyService.make()

    func testShowTabBar() {
        let config: Config = .make()
        let wallet: Wallet = .make()
        let navigationController = FakeNavigationController()

        let fas = FakeAnalyticsService()
        let keystore = FakeEtherKeystore(wallets: [wallet])
        let ac = AccountsCoordinator(
            config: .make(),
            navigationController: navigationController,
            keystore: keystore,
            analytics: fas,
            viewModel: .init(configuration: .changeWallets),
            walletBalanceService: FakeMultiWalletBalanceService(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            promptBackup: .make())

        let dep = WalletDataProcessingPipeline.make(wallet: wallet, server: .main)

        let coordinator = ActiveWalletCoordinator(
            navigationController: navigationController,
            activitiesPipeLine: dep.activitiesPipeLine,
            wallet: wallet,
            keystore: keystore,
            assetDefinitionStore: .make(),
            config: config,
            analytics: FakeAnalyticsService(),
            restartQueue: .init(),
            universalLinkCoordinator: FakeUniversalLinkCoordinator.make(),
            accountsCoordinator: ac,
            walletBalanceService: FakeMultiWalletBalanceService(),
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
            tokenActionsService: FakeSwapTokenService(),
            walletConnectCoordinator: .fake(),
            notificationService: .fake(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: TokenSwapper.make(),
            sessionsProvider: dep.sessionsProvider,
            tokenCollection: dep.pipeline,
            transactionsDataStore: dep.transactionsDataStore,
            tokensService: dep.tokensService,
            lock: FakeLock(),
            currencyService: currencyService,
            tokenScriptOverridesFileManager: .fake(),
            networkService: FakeNetworkService(),
            promptBackup: .make(),
            caip10AccountProvidable: AnyCAIP10AccountProvidable.make())

        coordinator.start(animated: false)

        XCTAssert(coordinator.navigationController.viewControllers[0] is AccountsViewController)
        let tabbarController = coordinator.navigationController.viewControllers[1] as? UITabBarController

        XCTAssertNotNil(tabbarController)
        if Features.default.isAvailable(.isSwapEnabled) {
            XCTAssert(tabbarController?.viewControllers!.count == 5)
            XCTAssert((tabbarController?.viewControllers?[0] as? UINavigationController)?.viewControllers[0] is TokensViewController)
            if Features.default.isAvailable(.isActivityEnabled) {
                XCTAssert((tabbarController?.viewControllers?[1] as? UINavigationController)?.viewControllers[0] is ActivitiesViewController)
            } else {
                XCTAssert((tabbarController?.viewControllers?[1] as? UINavigationController)?.viewControllers[0] is TransactionsViewController)
            }
            XCTAssertNotNil(tabbarController?.viewControllers?[2])
            XCTAssert((tabbarController?.viewControllers?[3] as? UINavigationController)?.viewControllers[0] is BrowserHomeViewController)
            XCTAssert((tabbarController?.viewControllers?[4] as? UINavigationController)?.viewControllers[0] is SettingsViewController)
        } else {
            XCTAssert(tabbarController?.viewControllers!.count == 4)
            XCTAssert((tabbarController?.viewControllers?[0] as? UINavigationController)?.viewControllers[0] is TokensViewController)
            XCTAssert((tabbarController?.viewControllers?[1] as? UINavigationController)?.viewControllers[0] is ActivitiesViewController)
            XCTAssert((tabbarController?.viewControllers?[2] as? UINavigationController)?.viewControllers[0] is BrowserHomeViewController)
            XCTAssert((tabbarController?.viewControllers?[3] as? UINavigationController)?.viewControllers[0] is SettingsViewController)
        }
    }
    // swiftlint:disable function_body_length
    func testChangeRecentlyUsedAccount() {
        let account1: Wallet = .make(address: AlphaWallet.Address(string: "0x1000000000000000000000000000000000000000")!)
        let account2: Wallet = .make(address: AlphaWallet.Address(string: "0x2000000000000000000000000000000000000000")!)

        let keystore = FakeEtherKeystore(
            wallets: [
                account1,
                account2
            ]
        )

        let navigationController = FakeNavigationController()
        let fas = FakeAnalyticsService()
        let ac = AccountsCoordinator(
            config: .make(),
            navigationController: navigationController,
            keystore: keystore,
            analytics: fas,
            viewModel: .init(configuration: .changeWallets),
            walletBalanceService: FakeMultiWalletBalanceService(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            promptBackup: .make())

        let dep1 = WalletDataProcessingPipeline.make(wallet: account1, server: .main)

        let c1 = ActiveWalletCoordinator(
            navigationController: FakeNavigationController(),
            activitiesPipeLine: dep1.activitiesPipeLine,
            wallet: account1,
            keystore: keystore,
            assetDefinitionStore: .make(),
            config: .make(),
            analytics: FakeAnalyticsService(),
            restartQueue: .init(),
            universalLinkCoordinator: FakeUniversalLinkCoordinator.make(),
            accountsCoordinator: ac,
            walletBalanceService: FakeMultiWalletBalanceService(),
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
            tokenActionsService: FakeSwapTokenService(),
            walletConnectCoordinator: .fake(),
            notificationService: .fake(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: TokenSwapper.make(),
            sessionsProvider: dep1.sessionsProvider,
            tokenCollection: dep1.pipeline,
            transactionsDataStore: dep1.transactionsDataStore,
            tokensService: dep1.tokensService,
            lock: FakeLock(),
            currencyService: currencyService,
            tokenScriptOverridesFileManager: .fake(),
            networkService: FakeNetworkService(),
            promptBackup: .make(),
            caip10AccountProvidable: AnyCAIP10AccountProvidable.make())

        c1.start(animated: false)

        XCTAssertEqual(c1.keystore.currentWallet, account1)

        let dep2 = WalletDataProcessingPipeline.make(wallet: account2, server: .main)

        let c2 = ActiveWalletCoordinator(
            navigationController: FakeNavigationController(),
            activitiesPipeLine: dep2.activitiesPipeLine,
            wallet: account2,
            keystore: keystore,
            assetDefinitionStore: .make(),
            config: .make(),
            analytics: FakeAnalyticsService(),
            restartQueue: .init(),
            universalLinkCoordinator: FakeUniversalLinkCoordinator.make(),
            accountsCoordinator: ac,
            walletBalanceService: FakeMultiWalletBalanceService(),
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
            tokenActionsService: FakeSwapTokenService(),
            walletConnectCoordinator: .fake(),
            notificationService: .fake(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: TokenSwapper.make(),
            sessionsProvider: dep2.sessionsProvider,
            tokenCollection: dep2.pipeline,
            transactionsDataStore: dep2.transactionsDataStore,
            tokensService: dep2.tokensService,
            lock: FakeLock(),
            currencyService: currencyService,
            tokenScriptOverridesFileManager: .fake(),
            networkService: FakeNetworkService(),
            promptBackup: .make(),
            caip10AccountProvidable: AnyCAIP10AccountProvidable.make())

        c1.start(animated: false)

        XCTAssertEqual(c2.keystore.currentWallet, account2)
    }
    // swiftlint:enable function_body_length

    func testShowSendFlow() {
        let wallet: Wallet = .make()
        let navigationController = FakeNavigationController()
        let fas = FakeAnalyticsService()
        let keystore = FakeEtherKeystore(wallets: [wallet])
        let ac = AccountsCoordinator(
            config: .make(),
            navigationController: navigationController,
            keystore: keystore,
            analytics: fas,
            viewModel: .init(configuration: .changeWallets),
            walletBalanceService: FakeMultiWalletBalanceService(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            promptBackup: .make())

        let dep = WalletDataProcessingPipeline.make(wallet: wallet, server: .main)

        let coordinator = ActiveWalletCoordinator(
                navigationController: FakeNavigationController(),
                activitiesPipeLine: dep.activitiesPipeLine,
                wallet: wallet,
                keystore: keystore,
                assetDefinitionStore: .make(),
                config: .make(),
                analytics: FakeAnalyticsService(),
                restartQueue: .init(),
                universalLinkCoordinator: FakeUniversalLinkCoordinator.make(),
                accountsCoordinator: ac,
                walletBalanceService: FakeMultiWalletBalanceService(),
                coinTickersFetcher: CoinTickersFetcherImpl.make(),
                tokenActionsService: FakeSwapTokenService(),
                walletConnectCoordinator: .fake(),
                notificationService: .fake(),
                blockiesGenerator: .make(),
                domainResolutionService: FakeDomainResolutionService(),
                tokenSwapper: TokenSwapper.make(),
                sessionsProvider: dep.sessionsProvider,
                tokenCollection: dep.pipeline,
                transactionsDataStore: dep.transactionsDataStore,
                tokensService: dep.tokensService,
                lock: FakeLock(),
                currencyService: currencyService,
                tokenScriptOverridesFileManager: .fake(),
                networkService: FakeNetworkService(),
                promptBackup: .make(),
                caip10AccountProvidable: AnyCAIP10AccountProvidable.make())

        coordinator.start(animated: false)
        coordinator.showPaymentFlow(
            for: .send(type: .transaction(TransactionType.nativeCryptocurrency(Token(), destination: .none, amount: .notSet))),
            server: .main,
            navigationController: coordinator.navigationController)

        XCTAssertTrue(coordinator.coordinators.last is PaymentCoordinator)
        XCTAssertTrue(coordinator.navigationController.viewControllers.last is SendViewController)
    }

    func testShowRequstFlow() {
        let wallet: Wallet = .make()
        let navigationController = FakeNavigationController()
        let fas = FakeAnalyticsService()
        let keystore = FakeEtherKeystore(wallets: [wallet])
        let ac = AccountsCoordinator(
            config: .make(),
            navigationController: navigationController,
            keystore: keystore,
            analytics: fas,
            viewModel: .init(configuration: .changeWallets),
            walletBalanceService: FakeMultiWalletBalanceService(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            promptBackup: .make())

        let dep = WalletDataProcessingPipeline.make(wallet: wallet, server: .main)

        let coordinator = ActiveWalletCoordinator(
            navigationController: navigationController,
            activitiesPipeLine: dep.activitiesPipeLine,
            wallet: wallet,
            keystore: keystore,
            assetDefinitionStore: .make(),
            config: .make(),
            analytics: FakeAnalyticsService(),
            restartQueue: .init(),
            universalLinkCoordinator: FakeUniversalLinkCoordinator.make(),
            accountsCoordinator: ac,
            walletBalanceService: FakeMultiWalletBalanceService(),
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
            tokenActionsService: FakeSwapTokenService(),
            walletConnectCoordinator: .fake(),
            notificationService: .fake(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: TokenSwapper.make(),
            sessionsProvider: dep.sessionsProvider,
            tokenCollection: dep.pipeline,
            transactionsDataStore: dep.transactionsDataStore,
            tokensService: dep.tokensService,
            lock: FakeLock(),
            currencyService: currencyService,
            tokenScriptOverridesFileManager: .fake(),
            networkService: FakeNetworkService(),
            promptBackup: .make(),
            caip10AccountProvidable: AnyCAIP10AccountProvidable.make())

        coordinator.start(animated: false)
        coordinator.showPaymentFlow(for: .request, server: .main, navigationController: coordinator.navigationController)

        XCTAssertTrue(coordinator.coordinators.last is PaymentCoordinator)
        XCTAssertTrue(coordinator.navigationController.viewControllers.last is RequestViewController)
    }

    func testShowTabDefault() {
        let navigationController = FakeNavigationController()
        let fas = FakeAnalyticsService()
        let keystore = FakeEtherKeystore()
        let ac = AccountsCoordinator(
            config: .make(),
            navigationController: navigationController,
            keystore: keystore,
            analytics: fas,
            viewModel: .init(configuration: .changeWallets),
            walletBalanceService: FakeMultiWalletBalanceService(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            promptBackup: .make())

        let wallet: Wallet = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: wallet, server: .main)

        let coordinator = ActiveWalletCoordinator(
            navigationController: navigationController,
            activitiesPipeLine: dep.activitiesPipeLine,
            wallet: wallet,
            keystore: keystore,
            assetDefinitionStore: .make(),
            config: .make(),
            analytics: FakeAnalyticsService(),
            restartQueue: .init(),
            universalLinkCoordinator: FakeUniversalLinkCoordinator.make(),
            accountsCoordinator: ac,
            walletBalanceService: FakeMultiWalletBalanceService(),
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
            tokenActionsService: FakeSwapTokenService(),
            walletConnectCoordinator: .fake(),
            notificationService: .fake(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: TokenSwapper.make(),
            sessionsProvider: dep.sessionsProvider,
            tokenCollection: dep.pipeline,
            transactionsDataStore: dep.transactionsDataStore,
            tokensService: dep.tokensService,
            lock: FakeLock(),
            currencyService: currencyService,
            tokenScriptOverridesFileManager: .fake(),
            networkService: FakeNetworkService(),
            promptBackup: .make(),
            caip10AccountProvidable: AnyCAIP10AccountProvidable.make())
        coordinator.start(animated: false)

        let viewController = (coordinator.tabBarController.selectedViewController as? UINavigationController)?.viewControllers[0]

        XCTAssert(viewController is TokensViewController)
    }

	//Commented out because the tokens tab has been moved to be under the More tab and will be moved
//    func testShowTabTokens() {
//        let coordinator = ActiveWalletCoordinator(
//            navigationController: FakeNavigationController(),
//            wallet: .make(),
//            keystore: FakeEtherKeystore(),
//            config: .make()
//        )
//        coordinator.showTabBar(for: .make())

//        coordinator.showTab(.tokens)

//        let viewController = (coordinator.tabBarController?.selectedViewController as? UINavigationController)?.viewControllers[0]

//        XCTAssert(viewController is TokensViewController)
//    }
    private var cancellable = Set<AnyCancellable>()
    func testShowTabAlphwaWalletWallet() throws {
        let keystore = FakeEtherKeystore()
        keystore.createHDWallet()
            .sink(receiveCompletion: { result  in
                guard case .failure = result else { return }
                XCTFail()
            }, receiveValue: { wallet in
                keystore.recentlyUsedWallet = wallet
                let navigationController = FakeNavigationController()
                let fas = FakeAnalyticsService()

                let ac: AccountsCoordinator = AccountsCoordinator(
                    config: .make(),
                    navigationController: navigationController,
                    keystore: keystore,
                    analytics: fas,
                    viewModel: .init(configuration: .changeWallets),
                    walletBalanceService: FakeMultiWalletBalanceService(),
                    blockiesGenerator: .make(),
                    domainResolutionService: FakeDomainResolutionService(),
                    promptBackup: .make())

                let dep = WalletDataProcessingPipeline.make(wallet: wallet, server: .main)

                let coordinator: ActiveWalletCoordinator = ActiveWalletCoordinator(
                        navigationController: navigationController,
                        activitiesPipeLine: dep.activitiesPipeLine,
                        wallet: wallet,
                        keystore: keystore,
                        assetDefinitionStore: .make(),
                        config: .make(),
                        analytics: FakeAnalyticsService(),
                        restartQueue: .init(),
                        universalLinkCoordinator: FakeUniversalLinkCoordinator.make(),
                        accountsCoordinator: ac,
                        walletBalanceService: FakeMultiWalletBalanceService(),
                        coinTickersFetcher: CoinTickersFetcherImpl.make(),
                        tokenActionsService: FakeSwapTokenService(),
                        walletConnectCoordinator: .fake(),
                        notificationService: .fake(),
                        blockiesGenerator: .make(),
                        domainResolutionService: FakeDomainResolutionService(),
                        tokenSwapper: TokenSwapper.make(),
                        sessionsProvider: dep.sessionsProvider,
                        tokenCollection: dep.pipeline,
                        transactionsDataStore: dep.transactionsDataStore,
                        tokensService: dep.tokensService,
                        lock: FakeLock(),
                        currencyService: self.currencyService,
                        tokenScriptOverridesFileManager: .fake(),
                        networkService: FakeNetworkService(),
                        promptBackup: .make(),
                        caip10AccountProvidable: AnyCAIP10AccountProvidable.make())

                coordinator.start(animated: false)

                coordinator.showTab(.tokens)

                let viewController = (coordinator.tabBarController.selectedViewController as? UINavigationController)?.viewControllers[0]

                XCTAssert(viewController is TokensViewController)
            }).store(in: &cancellable)
    }
}
// swiftlint:enable type_body_length
