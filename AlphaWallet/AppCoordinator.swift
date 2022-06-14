// Copyright SIX DAY LLC. All rights reserved.

import Combine
import UIKit
import PromiseKit

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
    lazy private var openSea: OpenSea = OpenSea(analyticsCoordinator: analyticsService, queue: .global())
    private let restartQueue = RestartTaskQueue()
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var activeWalletCoordinator: ActiveWalletCoordinator? {
        return coordinators.first { $0 is ActiveWalletCoordinator } as? ActiveWalletCoordinator
    }
    private let localStore: LocalStore = RealmLocalStore()
    private lazy var coinTickersFetcher: CoinTickersFetcherType = CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config)
    private lazy var walletBalanceService: WalletBalanceService = {
        return MultiWalletBalanceService(store: localStore, keystore: keystore, config: config, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsService, coinTickersFetcher: coinTickersFetcher, walletAddressesStore: walletAddressesStore)
    }()
    private var pendingActiveWalletCoordinator: ActiveWalletCoordinator?

    private lazy var accountsCoordinator: AccountsCoordinator = {
        let coordinator = AccountsCoordinator(
                config: config,
                navigationController: navigationController,
                keystore: keystore,
                analyticsCoordinator: analyticsService,
                viewModel: .init(configuration: .summary),
                walletBalanceService: walletBalanceService,
                blockiesGenerator: blockiesGenerator,
                domainResolutionService: domainResolutionService
        )
        coordinator.delegate = self

        return coordinator
    }()

    private lazy var tokenSwapper = TokenSwapper(reachabilityManager: ReachabilityManager(), sessions: sessionsSubject.eraseToAnyPublisher())

    private lazy var tokenActionsService: TokenActionsService = {
        let service = TokenActionsService()
        service.register(service: Ramp())
        service.register(service: Oneinch())

        let honeySwapService = HoneySwap()
        honeySwapService.theme = navigationController.traitCollection.honeyswapTheme
        service.register(service: honeySwapService)

        //NOTE: Disable uniswap swap provider

        //var uniswap = Uniswap()
        //uniswap.theme = navigationController.traitCollection.uniswapTheme

        //service.register(service: uniswap)

        var quickSwap = QuickSwap()
        quickSwap.theme = navigationController.traitCollection.uniswapTheme
        service.register(service: SwapTokenNativeProvider(tokenSwapper: tokenSwapper))
        service.register(service: quickSwap)
        service.register(service: ArbitrumBridge())
        service.register(service: xDaiBridge())

        return service
    }()

    private lazy var sessionsSubject = CurrentValueSubject<ServerDictionary<WalletSession>, Never>(.init())
    private lazy var walletConnectCoordinator: WalletConnectCoordinator = {
        let coordinator = WalletConnectCoordinator(keystore: keystore, navigationController: navigationController, analyticsCoordinator: analyticsService, domainResolutionService: domainResolutionService, config: config, sessionsSubject: sessionsSubject)

        return coordinator
    }()
    private var walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    lazy private var blockiesGenerator: BlockiesGenerator = BlockiesGenerator(openSea: openSea)
    lazy private var domainResolutionService: DomainResolutionServiceType = DomainResolutionService(blockiesGenerator: blockiesGenerator)

    private lazy var notificationService: NotificationService = {
        return NotificationService(sources: [], walletBalanceService: walletBalanceService)
    }()

    init(window: UIWindow, analyticsService: AnalyticsServiceType, keystore: Keystore, walletAddressesStore: WalletAddressesStore, navigationController: UINavigationController = .withOverridenBarAppearence()) throws {
        self.navigationController = navigationController
        self.window = window
        self.analyticsService = analyticsService
        self.keystore = keystore
        self.walletAddressesStore = walletAddressesStore
        self.legacyFileBasedKeystore = try LegacyFileBasedKeystore(keystore: keystore)

        super.init()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        setupSplashViewController(on: navigationController)
        bindWalletAddressesStore()
    }

    private func bindWalletAddressesStore() {
        walletAddressesStore
            .didRemoveWalletPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] account in
                guard let `self` = self else { return }

                self.config.deleteWalletName(forAccount: account.address)
                PromptBackupCoordinator(keystore: self.keystore, wallet: account, config: self.config, analyticsCoordinator: self.analyticsService).deleteWallet()
                TransactionsTracker.resetFetchingState(account: account, config: self.config)
                Erc1155TokenIdsFetcher.deleteForWallet(account.address)
                DatabaseMigration.removeRealmFiles(account: account)
                self.legacyFileBasedKeystore.delete(wallet: account)
                self.localStore.removeStore(forWallet: account)
            }.store(in: &cancelable)
    }

    func start() {
        initializers()
        appTracker.start()
        notificationService.registerForReceivingRemoteNotifications()
        applyStyle()

        setupAssetDefinitionStoreCoordinator()
        migrateToStoringRawPrivateKeysInKeychain()
        tokenActionsService.start()

        addCoordinator(walletConnectCoordinator)

        if let wallet = keystore.currentWallet, keystore.hasWallets {
            showActiveWallet(for: wallet, animated: false)
        } else {
            showInitialWalletCoordinator()
        }

        assetDefinitionStore.delegate = self
    }

    private func setupSplashViewController(on navigationController: UINavigationController) {
        navigationController.viewControllers = [
            SplashViewController()
        ]
        navigationController.setNavigationBarHidden(true, animated: false)
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

    @discardableResult func showActiveWallet(for wallet: Wallet, animated: Bool) -> ActiveWalletCoordinator {
        if let coordinator = initialWalletCreationCoordinator {
            removeCoordinator(coordinator)
        }

        let coordinator = ActiveWalletCoordinator(
                navigationController: navigationController,
                walletAddressesStore: walletAddressesStore,
                localStore: localStore,
                wallet: wallet,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
                config: config,
                appTracker: appTracker,
                analyticsCoordinator: analyticsService,
                openSea: openSea,
                restartQueue: restartQueue,
                universalLinkCoordinator: universalLinkCoordinator,
                accountsCoordinator: accountsCoordinator,
                walletBalanceService: walletBalanceService,
                coinTickersFetcher: coinTickersFetcher,
                tokenActionsService: tokenActionsService,
                walletConnectCoordinator: walletConnectCoordinator,
                sessionsSubject: sessionsSubject,
                notificationService: notificationService,
                blockiesGenerator: blockiesGenerator,
                domainResolutionService: domainResolutionService,
                tokenSwapper: tokenSwapper)

        coordinator.delegate = self

        addCoordinator(coordinator)
        addCoordinator(accountsCoordinator)

        coordinator.start(animated: animated)

        return coordinator
    }

    private func initializers() {
        let initializers: [Initializer] = [
            ConfigureImageStorage(),
            ConfigureApp(),
            CleanupWallets(keystore: keystore, walletAddressesStore: walletAddressesStore, config: config),
            SkipBackupFiles(legacyFileBasedKeystore: legacyFileBasedKeystore),
            ReportUsersWalletAddresses(walletAddressesStore: walletAddressesStore),
            CleanupPasscode(keystore: keystore)
        ]

        initializers.forEach { $0.perform() }
    }

    @objc func reset() {
        lock.deletePasscode()
        coordinators.removeAll()
        navigationController.dismiss(animated: true)

        showInitialWalletCoordinator()
    }

    func showInitialWalletCoordinator() {
        let coordinator = InitialWalletCreationCoordinator(config: config, navigationController: navigationController, keystore: keystore, analyticsCoordinator: analyticsService, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func showInitialNetworkSelectionCoordinator() {
        let coordinator = InitialNetworkSelectionCoordinator(config: config, navigationController: navigationController, restartTaskQueue: restartQueue)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func createInitialWalletIfMissing() {
        WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsService, domainResolutionService: domainResolutionService).createInitialWalletIfMissing()
    }

    private func showActiveWalletIfNeeded() {
        if activeWalletCoordinator != nil {
            //no-op
        } else if let pendingCoordinator = pendingActiveWalletCoordinator {
            addCoordinator(pendingCoordinator)
            pendingCoordinator.showTabBar(animated: false)

            pendingActiveWalletCoordinator = .none
        } else {
            //NOTE: wait until presented
        }
    }

    /// Return true if handled
    @discardableResult func handleUniversalLink(url: URL) -> Bool {
        createInitialWalletIfMissing()
        showActiveWalletIfNeeded()

        return universalLinkCoordinator.handleUniversalLinkOpen(url: url)
    }

    func handleUniversalLinkInPasteboard() {
        universalLinkCoordinator.handleUniversalLinkInPasteboard()
    }

    func launchUniversalScanner() {
        showActiveWalletIfNeeded()
        activeWalletCoordinator?.launchUniversalScanner()
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        activeWalletCoordinator?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        activeWalletCoordinator?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        activeWalletCoordinator?.didPressOpenWebPage(url, in: viewController)
    }

    func handleIntent(userActivity: NSUserActivity) -> Bool {
        if let type = userActivity.userInfo?[WalletQrCodeDonation.userInfoType.key] as? String, type == WalletQrCodeDonation.userInfoType.value {
            analyticsService.log(navigation: Analytics.Navigation.openShortcut, properties: [
                Analytics.Properties.type.rawValue: Analytics.ShortcutType.walletQrCode.rawValue
            ])
            activeWalletCoordinator?.showWalletQrCode()
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
        switch account.type {
        case .real:
            showInitialNetworkSelectionCoordinator()
        case .watch:
            guard let wallet = keystore.currentWallet else { return }
            showActiveWallet(for: wallet, animated: false)
        }
    }

}

extension AppCoordinator: InitialNetworkSelectionCoordinatorDelegate {
    func didSelect(networks: [RPCServer], in coordinator: InitialNetworkSelectionCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
        guard let wallet = keystore.currentWallet else { return }
        WhatsNewExperimentCoordinator.lastCreatedWalletTimestamp = Date()
        showActiveWallet(for: wallet, animated: false)
        DispatchQueue.main.async {
            WhereIsWalletAddressFoundOverlayView.show()
            self.restartQueue.add(.reloadServers(networks))
        }
    }
}

extension AppCoordinator: ActiveWalletCoordinatorDelegate {

    func didRestart(in coordinator: ActiveWalletCoordinator, reason: RestartReason, wallet: Wallet) {
        disconnectWalletConnectSessionsSelectively(for: reason, walletConnectCoordinator: walletConnectCoordinator)

        keystore.recentlyUsedWallet = wallet

        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)

        guard let wallet = keystore.currentWallet else { return }
        showActiveWallet(for: wallet, animated: false)
    }

    func showWallets(in coordinator: ActiveWalletCoordinator) {
        pendingActiveWalletCoordinator = coordinator
        removeCoordinator(coordinator)

        coordinator.navigationController.popViewController(animated: true)
        coordinator.navigationController.setNavigationBarHidden(false, animated: false)
    }

    func didCancel(in coordinator: ActiveWalletCoordinator) {
        removeCoordinator(coordinator)
        reset()
    }

    func didShowWallet(in coordinator: ActiveWalletCoordinator) {
        notificationService.requestToEnableNotification()
    }

    func assetDefinitionsOverrideViewController(for coordinator: ActiveWalletCoordinator) -> UIViewController? {
        return assetDefinitionStoreCoordinator?.createOverridesViewController()
    }

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: ActiveWalletCoordinator) {
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
        activeWalletCoordinator?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject, inViewController: viewController, completion: completion)
    }

    func completed(in coordinator: ImportMagicLinkCoordinator) {
        removeCoordinator(coordinator)
    }

    func didImported(contract: AlphaWallet.Address, in coordinator: ImportMagicLinkCoordinator) {
        activeWalletCoordinator?.addImported(contract: contract, forServer: coordinator.server)
    }
}

extension AppCoordinator: AssetDefinitionStoreCoordinatorDelegate {

    func show(error: Error, for viewController: AssetDefinitionStoreCoordinator) {
        activeWalletCoordinator?.show(error: error)
    }

    func addedTokenScript(forContract contract: AlphaWallet.Address, forServer server: RPCServer, destinationFileInUse: Bool, filename: String) {
        activeWalletCoordinator?.addImported(contract: contract, forServer: server)

        if !destinationFileInUse {
            activeWalletCoordinator?.show(openedURL: filename)
        }
    }
}

extension AppCoordinator: AssetDefinitionStoreDelegate {
    func listOfBadTokenScriptFilesChanged(in: AssetDefinitionStore ) {
        activeWalletCoordinator?.listOfBadTokenScriptFilesChanged(fileNames: assetDefinitionStore.listOfBadTokenScriptFiles + assetDefinitionStore.conflictingTokenScriptFileNames.all)
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
            let account = resolver.sessions.anyValue.account
            let paymentFlowResolver = PaymentFlowFromEip681UrlResolver(tokensDataStore: resolver.tokensDataStore, account: account, assetDefinitionStore: assetDefinitionStore, config: config)
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

            if resolver.sessions[safe: server] != nil {
                let coordinator = ImportMagicLinkCoordinator(
                    analyticsCoordinator: analyticsService,
                    sessions: resolver.sessions,
                    config: config,
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
        return activeWalletCoordinator
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
        //no-op
    }

    func didCancel(in coordinator: AccountsCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
    }

    func didFinishBackup(account: AlphaWallet.Address, in coordinator: AccountsCoordinator) {
        activeWalletCoordinator?.didFinishBackup(account: account)
    }

    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        //NOTE: Push existing view controller to the app navigation stack
        if let pendingCoordinator = pendingActiveWalletCoordinator, keystore.currentWallet == account {
            addCoordinator(pendingCoordinator)

            pendingCoordinator.showTabBar(animated: true)
        } else {
            disconnectWalletConnectSessionsSelectively(for: .walletChange, walletConnectCoordinator: walletConnectCoordinator)
            showActiveWallet(for: account, animated: true)
        }

        pendingActiveWalletCoordinator = .none
    }
}

