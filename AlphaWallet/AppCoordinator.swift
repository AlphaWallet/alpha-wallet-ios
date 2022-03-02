// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import PromiseKit
import Combine

class AppCoordinator: NSObject, Coordinator {
    private let config = Config()
    private let legacyFileBasedKeystore: LegacyFileBasedKeystore
    private let lock = Lock()
    private var keystore: Keystore
    private let assetDefinitionStore = AssetDefinitionStore()
    private let window: UIWindow
    private var appTracker = AppTracker()
    private var assetDefinitionStoreCoordinator: AssetDefinitionStoreCoordinator? {
        return coordinators.first { $0 is AssetDefinitionStoreCoordinator } as? AssetDefinitionStoreCoordinator
    }
    private var pushNotificationsCoordinator: PushNotificationsCoordinator? {
        return coordinators.first { $0 is PushNotificationsCoordinator } as? PushNotificationsCoordinator
    }
    private var initialWalletCreationCoordinator: InitialWalletCreationCoordinator? {
        return coordinators.compactMap { $0 as? InitialWalletCreationCoordinator }.first
    }
    var promptBackupCoordinator: PromptBackupCoordinator? {
        return coordinators.compactMap { $0 as? PromptBackupCoordinator }.first
    }

    private lazy var universalLinkCoordinator: UniversalLinkCoordinatorType = {
        let coordinator = UniversalLinkCoordinator()
        coordinator.delegate = self

        return coordinator
    }()

    private var analyticsService: AnalyticsServiceType
    private let restartQueue = RestartTaskQueue()
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var inCoordinator: InCoordinator? {
        return coordinators.first { $0 is InCoordinator } as? InCoordinator
    }
    private lazy var coinTickersFetcher: CoinTickersFetcherType = CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config)
    private lazy var walletBalanceCoordinator: WalletBalanceCoordinatorType = WalletBalanceCoordinator(keystore: keystore, config: config, assetDefinitionStore: assetDefinitionStore, coinTickersFetcher: coinTickersFetcher)

    private var pendingInCoordinator: InCoordinator?

    private lazy var accountsCoordinator: AccountsCoordinator = {
        let coordinator = AccountsCoordinator(
                config: config,
                navigationController: navigationController,
                keystore: keystore,
                promptBackupCoordinator: promptBackupCoordinator,
                analyticsCoordinator: analyticsService,
                viewModel: .init(configuration: .summary),
                walletBalanceCoordinator: walletBalanceCoordinator
        )
        coordinator.delegate = self

        return coordinator
    }()

    private lazy var oneInchSwapService = Oneinch()
    private lazy var rampBuyService = Ramp()
    private lazy var tokenActionsService: TokenActionsServiceType = {
        let service = TokenActionsService()
        service.register(service: rampBuyService)
        service.register(service: oneInchSwapService)

        let honeySwapService = HoneySwap()
        honeySwapService.theme = navigationController.traitCollection.honeyswapTheme
        service.register(service: honeySwapService)

        //NOTE: Disable uniswap swap provider

        //var uniswap = Uniswap()
        //uniswap.theme = navigationController.traitCollection.uniswapTheme

        //service.register(service: uniswap)

        var quickSwap = QuickSwap()
        quickSwap.theme = navigationController.traitCollection.uniswapTheme

        service.register(service: quickSwap)
        service.register(service: ArbitrumBridge())
        service.register(service: xDaiBridge())

        return service
    }()

    private lazy var selectedWalletSessionsSubject = CurrentValueSubject<ServerDictionary<WalletSession>, Never>(.init())
    private lazy var walletConnectCoordinator: WalletConnectCoordinator = {
        let coordinator = WalletConnectCoordinator(keystore: keystore, navigationController: navigationController, analyticsCoordinator: analyticsService, config: config, sessionsSubject: selectedWalletSessionsSubject)

        return coordinator
    }()

    init(window: UIWindow, analyticsService: AnalyticsServiceType, keystore: Keystore, navigationController: UINavigationController = .withOverridenBarAppearence()) throws {
        self.navigationController = navigationController
        self.window = window
        self.analyticsService = analyticsService
        self.keystore = keystore
        self.legacyFileBasedKeystore = try LegacyFileBasedKeystore(keystore: keystore)

        super.init()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        setupSplashViewController(on: navigationController)
    }

    func start() {
        if isRunningTests() {
            try! RealmConfiguration.removeWalletsFolderForTests()
            JsonWalletAddressesStore.removeWalletsFolderForTests()
            startImpl()
        } else {
            DispatchQueue.main.async {
                let succeeded = self.startImpl()
                if succeeded {
                    return
                } else {
                    self.retryStart()
                }
            }
        }
    }

    private func setupSplashViewController(on navigationController: UINavigationController) {
        navigationController.viewControllers = [
            SplashViewController()
        ]
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    private func retryStart() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let succeeded = self.startImpl()
            if succeeded {
                return
            } else {
                self.retryStart()
            }
        }
    }

    //This function exist to handle what we think is a rare (but hard to reproduce) occurrence that NSUserDefaults are not accessible for a short while during startup. If that happens, we delay the "launch" and check again. If the app is killed by the iOS launch time watchdog, so be it. Better than to let the user create a wallet and wipe the list of wallets and lose access
    @discardableResult private func startImpl() -> Bool {
        if MigrationInitializer.hasRealmDatabasesForWallet && !keystore.hasWallets && !isRunningTests() {
            return false
        }

        MigrationInitializer.removeWalletsIfRealmFilesMissed(keystore: keystore)

        initializers()
        appTracker.start()
        handleNotifications()
        applyStyle()

        setupAssetDefinitionStoreCoordinator()
        migrateToStoringRawPrivateKeysInKeychain()
        walletBalanceCoordinator.start()
        oneInchSwapService.fetchSupportedTokens()
        rampBuyService.fetchSupportedTokens()

        addCoordinator(walletConnectCoordinator)

        if keystore.hasWallets {
            showTransactions(for: keystore.currentWallet, animated: false)
        } else {
            showInitialWalletCoordinator()
        }

        assetDefinitionStore.delegate = self
        return true
    }

    private func migrateToStoringRawPrivateKeysInKeychain() {
        legacyFileBasedKeystore.migrateKeystoreFilesToRawPrivateKeysInKeychain()
    }

    private func setupAssetDefinitionStoreCoordinator() {
        let coordinator = AssetDefinitionStoreCoordinator(assetDefinitionStore: assetDefinitionStore)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    @discardableResult func showTransactions(for wallet: Wallet, animated: Bool) -> InCoordinator {
        if let coordinator = initialWalletCreationCoordinator {
            removeCoordinator(coordinator)
        }

        if let coordinator = promptBackupCoordinator {
            removeCoordinator(coordinator)
        }

        let promptBackupCoordinator = PromptBackupCoordinator(keystore: keystore, wallet: wallet, config: config, analyticsCoordinator: analyticsService)
        promptBackupCoordinator.start()
        addCoordinator(promptBackupCoordinator)

        let coordinator = InCoordinator(
                navigationController: navigationController,
                wallet: wallet,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
                config: config,
                appTracker: appTracker,
                analyticsCoordinator: analyticsService,
                restartQueue: restartQueue,
                universalLinkCoordinator: universalLinkCoordinator,
                promptBackupCoordinator: promptBackupCoordinator,
                accountsCoordinator: accountsCoordinator,
                walletBalanceCoordinator: walletBalanceCoordinator,
                coinTickersFetcher: coinTickersFetcher,
                tokenActionsService: tokenActionsService,
                walletConnectCoordinator: walletConnectCoordinator,
                sessionsSubject: selectedWalletSessionsSubject
        )

        coordinator.delegate = self

        addCoordinator(coordinator)
        addCoordinator(accountsCoordinator)

        coordinator.start(animated: animated)

        return coordinator
    }

    private func initializers() {
        var paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        paths.append(legacyFileBasedKeystore.keystoreDirectory)

        let initializers: [Initializer] = [
            SkipBackupFilesInitializer(paths: paths),
        ]
        initializers.forEach { $0.perform() }
        //We should clean passcode if there is no wallets. This step is required for app reinstall.
        if !keystore.hasWallets {
            lock.clear()
        }
    }

    private func handleNotifications() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        let coordinator = PushNotificationsCoordinator()
        coordinator.start()
        addCoordinator(coordinator)
    }

    @objc func reset() {
        lock.deletePasscode()
        coordinators.removeAll()
        navigationController.dismiss(animated: true)

        showInitialWalletCoordinator()
    }

    func showInitialWalletCoordinator() {
        let coordinator = InitialWalletCreationCoordinator(config: config, navigationController: navigationController, keystore: keystore, analyticsCoordinator: analyticsService)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func createInitialWalletIfMissing() {
        WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsService).createInitialWalletIfMissing()
    }

    private func showTransactionsIfNeeded() {
        if inCoordinator != nil {
            //no-op
        } else if let pendingCoordinator = pendingInCoordinator {
            addCoordinator(pendingCoordinator)
            pendingCoordinator.showTabBar(animated: false)

            pendingInCoordinator = .none
        } else {
            //NOTE: wait until presented
        }
    }

    /// Return true if handled
    @discardableResult func handleUniversalLink(url: URL) -> Bool {
        createInitialWalletIfMissing()
        showTransactionsIfNeeded()

        return universalLinkCoordinator.handleUniversalLinkOpen(url: url)
    }

    func handleUniversalLinkInPasteboard() {
        universalLinkCoordinator.handleUniversalLinkInPasteboard()
    }

    func launchUniversalScanner() {
        showTransactionsIfNeeded()
        inCoordinator?.launchUniversalScanner()
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        inCoordinator?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        inCoordinator?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        inCoordinator?.didPressOpenWebPage(url, in: viewController)
    }

    func handleIntent(userActivity: NSUserActivity) -> Bool {
        if let type = userActivity.userInfo?[WalletQrCodeDonation.userInfoType.key] as? String, type == WalletQrCodeDonation.userInfoType.value {
            analyticsService.log(navigation: Analytics.Navigation.openShortcut, properties: [
                Analytics.Properties.type.rawValue: Analytics.ShortcutType.walletQrCode.rawValue
            ])
            inCoordinator?.showWalletQrCode()
            return true
        } else {
            return false
        }
    }
}

extension AppCoordinator: InitialWalletCreationCoordinatorDelegate {

    func didCancel(in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)

        removeCoordinator(coordinator)

        showTransactions(for: keystore.currentWallet, animated: false)
    }
}

extension AppCoordinator: InCoordinatorDelegate {

    func didRestart(in coordinator: InCoordinator, reason: RestartReason, wallet: Wallet) {
        disconnectWalletConnectSessionsSelectively(for: reason, walletConnectCoordinator: walletConnectCoordinator)

        keystore.recentlyUsedWallet = wallet

        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)

        showTransactions(for: keystore.currentWallet, animated: false)
    }

    func showWallets(in coordinator: InCoordinator) {
        pendingInCoordinator = coordinator
        removeCoordinator(coordinator)

        //NOTE: refactor with more better solution
        accountsCoordinator.promptBackupCoordinator = promptBackupCoordinator

        coordinator.navigationController.popViewController(animated: true)
        coordinator.navigationController.setNavigationBarHidden(false, animated: false)
    }

    func didCancel(in coordinator: InCoordinator) {
        removeCoordinator(coordinator)
        reset()
    }

    func didUpdateAccounts(in coordinator: InCoordinator) {
        //no-op
    }

    func didShowWallet(in coordinator: InCoordinator) {
        pushNotificationsCoordinator?.didShowWallet(in: coordinator.navigationController)
    }

    func assetDefinitionsOverrideViewController(for coordinator: InCoordinator) -> UIViewController? {
        return assetDefinitionStoreCoordinator?.createOverridesViewController()
    }

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: InCoordinator) {
        handleUniversalLink(url: url)
    }
}

extension AppCoordinator: ImportMagicLinkCoordinatorDelegate {

    func viewControllerForPresenting(in coordinator: ImportMagicLinkCoordinator) -> UIViewController? {
        if var top = window.rootViewController {
            while let vc = top.presentedViewController {
                top = vc
            }
            return top
        } else {
            return nil
        }
    }

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, inViewController viewController: ImportMagicTokenViewController, completion: @escaping (Bool) -> Void) {
        inCoordinator?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject, inViewController: viewController, completion: completion)
    }

    func completed(in coordinator: ImportMagicLinkCoordinator) {
        removeCoordinator(coordinator)
    }

    func didImported(contract: AlphaWallet.Address, in coordinator: ImportMagicLinkCoordinator) {
        inCoordinator?.addImported(contract: contract, forServer: coordinator.server)
    }
}

extension AppCoordinator: AssetDefinitionStoreCoordinatorDelegate {

    func show(error: Error, for viewController: AssetDefinitionStoreCoordinator) {
        inCoordinator?.show(error: error)
    }

    func addedTokenScript(forContract contract: AlphaWallet.Address, forServer server: RPCServer, destinationFileInUse: Bool, filename: String) {
        inCoordinator?.addImported(contract: contract, forServer: server)

        if !destinationFileInUse {
            inCoordinator?.show(openedURL: filename)
        }
    }
}

extension AppCoordinator: AssetDefinitionStoreDelegate {
    func listOfBadTokenScriptFilesChanged(in: AssetDefinitionStore ) {
        inCoordinator?.listOfBadTokenScriptFilesChanged(fileNames: assetDefinitionStore.listOfBadTokenScriptFiles + assetDefinitionStore.conflictingTokenScriptFileNames.all)
    }
}

extension AppCoordinator: UniversalLinkCoordinatorDelegate {

    private var hasImportMagicLinkCoordinator: ImportMagicLinkCoordinator? {
        return coordinators.compactMap { $0 as? ImportMagicLinkCoordinator }.first
    }

    func handle(url: DeepLink, for resolver: UrlSchemeResolver) {
        switch url {
        case .maybeFileUrl(let url):
            guard let coordinator = assetDefinitionStoreCoordinator else { return }
            coordinator.handleOpen(url: url)
        case .eip681(let url):
            let paymentFlowResolver = PaymentFlowFromEip681UrlResolver(tokensDataStore: resolver.tokensDataStore, assetDefinitionStore: assetDefinitionStore, config: config)
            guard let promise = paymentFlowResolver.resolve(url: url) else { return }
            firstly {
                promise
            }.done { (paymentFlow: PaymentFlow, server: RPCServer) in
                resolver.showPaymentFlow(for: paymentFlow, server: server, navigationController: resolver.presentationNavigationController)
            }.cauterize()
        case .walletConnect(let url, let source):
            switch source {
            case .safariExtension:
                analyticsService.log(action: Analytics.Action.tapSafariExtensionRewrittenUrl, properties: [
                    Analytics.Properties.type.rawValue: "walletConnect"
                ])
            case .mobileLinking:
                break
            }
            resolver.openWalletConnectSession(url: url)
        case .embeddedUrl(_, let url):
            resolver.openURLInBrowser(url: url)
        case .shareContentAction(let action):
            switch action {
            case .string, .openApp:
                break //NOTE: here we can add parsing Addresses from string
            case .url(let url):
                resolver.openURLInBrowser(url: url)
            }
        case .magicLink(_, let server, let url):
            guard hasImportMagicLinkCoordinator == nil else { return }

            if config.enabledServers.contains(server) {
                let coordinator = ImportMagicLinkCoordinator(
                    analyticsCoordinator: analyticsService,
                    wallet: keystore.currentWallet,
                    config: config,
                    ethPrice: resolver.nativeCryptoCurrencyPrices[server],
                    ethBalance: resolver.nativeCryptoCurrencyBalances[server],
                    tokensDatastore: resolver.tokensDataStore,
                    assetDefinitionStore: assetDefinitionStore,
                    url: url,
                    server: server,
                    keystore: keystore
                )

                coordinator.delegate = self
                let handled = coordinator.start(url: url)

                if handled {
                    addCoordinator(coordinator)
                }
            } else {
                let coordinator = ServerUnavailableCoordinator(navigationController: navigationController, servers: [server], coordinator: self)
                coordinator.start().done { _ in
                    //no-op
                }.cauterize()
            }
        }
    }

    func resolve(for coordinator: UniversalLinkCoordinator) -> UrlSchemeResolver? {
        return inCoordinator
    }
}

extension AppCoordinator: AccountsCoordinatorDelegate {

    private func disconnectWalletConnectSessionsSelectively(for reason: RestartReason, walletConnectCoordinator: WalletConnectCoordinator) {
        switch reason {
        case .changeLocalization, .walletChange:
            break //no op
        case .serverChange:
            walletConnectCoordinator.disconnect(sessionsToDisconnect: .allExcept(config.enabledServers))
        }
    }

    func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
    }

    func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        TransactionsStorage.deleteAllTransactions(realm: Wallet.functional.realm(forAccount: account))
        TransactionsTracker.resetFetchingState(account: account, config: config)
    }

    func didCancel(in coordinator: AccountsCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
    }

    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        //NOTE: Push existing view controller to the app navigation stack
        if let pendingCoordinator = pendingInCoordinator, keystore.currentWallet == account {
            addCoordinator(pendingCoordinator)

            pendingCoordinator.showTabBar(animated: true)
        } else {
            disconnectWalletConnectSessionsSelectively(for: .walletChange, walletConnectCoordinator: walletConnectCoordinator)
            showTransactions(for: account, animated: true)
        }

        pendingInCoordinator = .none
    }
}

