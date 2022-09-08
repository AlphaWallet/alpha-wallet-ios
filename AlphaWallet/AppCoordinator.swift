// Copyright SIX DAY LLC. All rights reserved.

import Combine
import UIKit
import PromiseKit
import AlphaWalletCore
import AlphaWalletFoundation

extension TokenScript {
    static let baseTokenScriptFiles: [TokenType: String] = [
        .erc20: (try! String(contentsOf: R.file.erc20TokenScriptTsml()!)),
        .erc721: (try! String(contentsOf: R.file.erc721TokenScriptTsml()!)),
    ]
}

class AppCoordinator: NSObject, Coordinator {
    private let config = Config()
    private let legacyFileBasedKeystore: LegacyFileBasedKeystore
    private lazy var lock: Lock = SecuredLock(securedStorage: securedStorage)
    private var keystore: Keystore
    private let assetDefinitionStore = AssetDefinitionStore(baseTokenScriptFiles: TokenScript.baseTokenScriptFiles)
    private let window: UIWindow
    private var appTracker = AppTracker()
    //TODO rename and replace type? Not Initializer but similar as of writing
    private var services: [Initializer] = []
    private var assetDefinitionStoreCoordinator: AssetDefinitionStoreCoordinator? {
        return coordinators.first { $0 is AssetDefinitionStoreCoordinator } as? AssetDefinitionStoreCoordinator
    }
    private var initialWalletCreationCoordinator: InitialWalletCreationCoordinator? {
        return coordinators.compactMap { $0 as? InitialWalletCreationCoordinator }.first
    }
    var promptBackupCoordinator: PromptBackupCoordinator? {
        return coordinators.compactMap { $0 as? PromptBackupCoordinator }.first
    }

    private lazy var protectionCoordinator: ProtectionCoordinator = {
        return ProtectionCoordinator(lock: lock)
    }()
    private lazy var universalLinkService: UniversalLinkService = {
        let coordinator = UniversalLinkService(analytics: analytics)
        coordinator.delegate = self

        return coordinator
    }()

    private let analytics: AnalyticsServiceType
    lazy private var openSea: OpenSea = OpenSea(analytics: analytics, queue: .global())
    private let restartQueue = RestartTaskQueue()
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var activeWalletCoordinator: ActiveWalletCoordinator? {
        return coordinators.first { $0 is ActiveWalletCoordinator } as? ActiveWalletCoordinator
    }
    private lazy var coinTickersFetcher: CoinTickersFetcher = {
        let networkProvider: CoinGeckoNetworkProviderType
        let persistentStorage: CoinTickersStorage & ChartHistoryStorage & TickerIdsStorage
        if isRunningTests() {
            networkProvider = FakeCoinGeckoNetworkProvider()
            persistentStorage = RealmStore(realm: fakeRealm(), name: "org.alphawallet.swift.realmStore.shared.wallet")
        } else {
            networkProvider = CoinGeckoNetworkProvider(provider: AlphaWalletProviderFactory.makeProvider())
            persistentStorage = RealmStore.shared
        }

        let coinGeckoTickerIdsFetcher = CoinGeckoTickerIdsFetcher(networkProvider: networkProvider, storage: persistentStorage, config: config)
        let fileTokenEntriesProvider = FileTokenEntriesProvider()

        let tickerIdsFetcher: TickerIdsFetcher = TickerIdsFetcherImpl(providers: [
            InMemoryTickerIdsFetcher(storage: persistentStorage),
            coinGeckoTickerIdsFetcher,
            AlphaWalletRemoteTickerIdsFetcher(provider: fileTokenEntriesProvider, tickerIdsFetcher: coinGeckoTickerIdsFetcher)
        ])

        return CoinGeckoTickersFetcher(networkProvider: networkProvider, storage: persistentStorage, tickerIdsFetcher: tickerIdsFetcher)
    }()
    private lazy var nftProvider: NFTProvider = {
        let queue: DispatchQueue = DispatchQueue(label: "org.alphawallet.swift.walletBalance")
        return AlphaWalletNFTProvider(analytics: analytics, queue: queue)
    }()
    private lazy var dependencyProvider: WalletDependencyContainer = {
        WalletComponentsFactory(analytics: analytics, nftProvider: nftProvider, assetDefinitionStore: assetDefinitionStore, coinTickersFetcher: coinTickersFetcher, config: config)
    }()
    private lazy var walletBalanceService: WalletBalanceService = {
        let service = MultiWalletBalanceService(walletAddressesStore: walletAddressesStore, dependencyContainer: dependencyProvider)
        service.start()
        return service
    }()
    private var pendingActiveWalletCoordinator: ActiveWalletCoordinator?

    private lazy var accountsCoordinator: AccountsCoordinator = {
        let coordinator = AccountsCoordinator(
                config: config,
                navigationController: navigationController,
                keystore: keystore,
                analytics: analytics,
                viewModel: .init(configuration: .summary),
                walletBalanceService: walletBalanceService,
                blockiesGenerator: blockiesGenerator,
                domainResolutionService: domainResolutionService
        )
        coordinator.delegate = self

        return coordinator
    }()
    private lazy var tokenSwapper = TokenSwapper(reachabilityManager: ReachabilityManager(), sessionProvider: sessionProvider)
    private lazy var tokenActionsService: TokenActionsService = {
        let service = TokenActionsService()
        service.register(service: BuyTokenProvider(subProviders: [
            CoinBase(action: R.string.localizable.aWalletTokenBuyOnCoinBaseTitle()),
            Ramp(action: R.string.localizable.aWalletTokenBuyOnRampTitle())
        ], action: R.string.localizable.aWalletTokenBuyTitle()))

        let honeySwapService = HoneySwap(action: R.string.localizable.aWalletTokenErc20ExchangeHoneyswapButtonTitle())
        honeySwapService.theme = navigationController.traitCollection.honeyswapTheme

        let quickSwap = QuickSwap(action: R.string.localizable.aWalletTokenErc20ExchangeOnQuickSwapButtonTitle())
        quickSwap.theme = navigationController.traitCollection.uniswapTheme
        var availableSwapProviders: [SupportedTokenActionsProvider & TokenActionProvider] = [
            honeySwapService,
            quickSwap,
            Oneinch(action: R.string.localizable.aWalletTokenErc20ExchangeOn1inchButtonTitle()),
            Carthage(action: R.string.localizable.aWalletTokenErc20ExchangeCarthageButtonTitle()),
            //uniswap
        ]
        availableSwapProviders += Features.default.isAvailable(.isSwapEnabled) ? [SwapTokenNativeProvider(tokenSwapper: tokenSwapper)] : []

        service.register(service: SwapTokenProvider(subProviders: availableSwapProviders, action: R.string.localizable.aWalletTokenSwapButtonTitle()))
        service.register(service: ArbitrumBridge(action: R.string.localizable.aWalletTokenArbitrumBridgeButtonTitle()))
        service.register(service: xDaiBridge(action: R.string.localizable.aWalletTokenXDaiBridgeButtonTitle()))

        return service
    }()

    private lazy var walletConnectCoordinator: WalletConnectCoordinator = {
        let coordinator = WalletConnectCoordinator(keystore: keystore, navigationController: navigationController, analytics: analytics, domainResolutionService: domainResolutionService, config: config, sessionProvider: sessionProvider, assetDefinitionStore: assetDefinitionStore)

        return coordinator
    }()
    private var walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    private let sharedEnsRecordsStorage: EnsRecordsStorage = {
        let storage: EnsRecordsStorage = RealmStore.shared
        return storage
    }()
    lazy private var blockiesGenerator: BlockiesGenerator = BlockiesGenerator(openSea: openSea, storage: sharedEnsRecordsStorage)
    lazy private var domainResolutionService: DomainResolutionServiceType = DomainResolutionService(blockiesGenerator: blockiesGenerator, storage: sharedEnsRecordsStorage)
    private lazy var walletApiCoordinator: WalletApiCoordinator = {
        let coordinator = WalletApiCoordinator(keystore: keystore, navigationController: navigationController, analytics: analytics, serviceProvider: sessionProvider)
        coordinator.delegate = self

        return coordinator
    }()
    private lazy var notificationService: NotificationService = {
        let pushNotificationsService = UNUserNotificationsService()
        let notificationService = LocalNotificationService()
        return NotificationService(sources: [], walletBalanceService: walletBalanceService, notificationService: notificationService, pushNotificationsService: pushNotificationsService)
    }()

    private lazy var sessionProvider = SessionsProvider(config: config, analytics: analytics)
    private let securedStorage: SecuredPasswordStorage & SecuredStorage
    init(window: UIWindow, analytics: AnalyticsServiceType, keystore: Keystore, walletAddressesStore: WalletAddressesStore, navigationController: UINavigationController = .withOverridenBarAppearence(), securedStorage: SecuredPasswordStorage & SecuredStorage) throws {
        self.navigationController = navigationController
        self.window = window
        self.analytics = analytics
        self.keystore = keystore
        self.walletAddressesStore = walletAddressesStore
        self.securedStorage = securedStorage
        self.legacyFileBasedKeystore = try LegacyFileBasedKeystore(securedStorage: securedStorage, keystore: keystore)

        super.init()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        setupSplashViewController(on: navigationController)
        bindWalletAddressesStore()
    }

    private func bindWalletAddressesStore() {
        walletAddressesStore
            .didRemoveWalletPublisher
            .sink { [weak self] account in
                guard let `self` = self else { return }

                //TODO: pass ref
                FileWalletStorage().addOrUpdate(name: nil, for: account.address)
                PromptBackupCoordinator(keystore: self.keystore, wallet: account, config: self.config, analytics: self.analytics).deleteWallet()
                TransactionsTracker.resetFetchingState(account: account, config: self.config)
                Erc1155TokenIdsFetcher.deleteForWallet(account.address)
                DatabaseMigration.removeRealmFiles(account: account)
                self.legacyFileBasedKeystore.delete(wallet: account)
            }.store(in: &cancelable)
    }

    func start() {
        if Features.default.isAvailable(.isLoggingEnabledForTickerMatches) {
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                infoLog("Ticker ID positive matching counts: \(TickerIdFilter.matchCounts)")
            }
        }

        protectionCoordinator.didFinishLaunchingWithOptions()
        initializers()
        runServices()
        appTracker.start()
        notificationService.registerForReceivingRemoteNotifications()

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

    func applicationWillResignActive() {
        protectionCoordinator.applicationWillResignActive()
    }

    func applicationDidBecomeActive() {
        protectionCoordinator.applicationDidBecomeActive()
        handleUniversalLinkInPasteboard()
    }

    func applicationDidEnterBackground() {
        protectionCoordinator.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground() {
        protectionCoordinator.applicationWillEnterForeground()
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

        let dep = dependencyProvider.makeDependencies(for: wallet)
        dep.sessionsProvider.start(wallet: wallet)
        dep.fetcher.start()
        dep.pipeline.start()

        walletConnectCoordinator.configure(with: dep.pipeline)

        let coordinator = ActiveWalletCoordinator(
                navigationController: navigationController,
                walletAddressesStore: walletAddressesStore,
                store: dep.store,
                wallet: wallet,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
                config: config,
                appTracker: appTracker,
                analytics: analytics,
                openSea: openSea,
                restartQueue: restartQueue,
                universalLinkCoordinator: universalLinkService,
                accountsCoordinator: accountsCoordinator,
                walletBalanceService: walletBalanceService,
                coinTickersFetcher: coinTickersFetcher,
                tokenActionsService: tokenActionsService,
                walletConnectCoordinator: walletConnectCoordinator,
                notificationService: notificationService,
                blockiesGenerator: blockiesGenerator,
                domainResolutionService: domainResolutionService,
                tokenSwapper: tokenSwapper,
                sessionsProvider: dep.sessionsProvider,
                tokenCollection: dep.pipeline,
                importToken: dep.importToken,
                transactionsDataStore: dep.transactionsDataStore,
                tokensService: dep.tokensService,
                lock: lock)

        coordinator.delegate = self

        addCoordinator(coordinator)
        addCoordinator(accountsCoordinator)

        coordinator.start(animated: animated)

        sessionProvider.start(sessions: dep.sessionsProvider.sessions)

        return coordinator
    }

    private func initializers() {
        let initializers: [Initializer] = [
            ConfigureImageStorage(),
            ConfigureApp(),
            CleanupWallets(keystore: keystore, walletAddressesStore: walletAddressesStore, config: config),
            SkipBackupFiles(legacyFileBasedKeystore: legacyFileBasedKeystore),
            CleanupPasscode(keystore: keystore, lock: lock)
        ]

        initializers.forEach { $0.perform() }
    }

    private func runServices() {
        services = [
            ReportUsersWalletAddresses(walletAddressesStore: walletAddressesStore),
            ReportUsersActiveChains(config: config),
        ]
        services.forEach { $0.perform() }
    }

    @objc func reset() {
        lock.deletePasscode()
        coordinators.removeAll()
        navigationController.dismiss(animated: true)

        showInitialWalletCoordinator()
    }

    func showInitialWalletCoordinator() {
        let coordinator = InitialWalletCreationCoordinator(config: config, navigationController: navigationController, keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
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
        WalletCoordinator(config: config, keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService).createInitialWalletIfMissing()
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
    @discardableResult func handleUniversalLink(url: URL, source: UrlSource) -> Bool {
        createInitialWalletIfMissing()
        showActiveWalletIfNeeded()

        return universalLinkService.handleUniversalLink(url: url, source: source)
    }

    func handleUniversalLinkInPasteboard() {
        universalLinkService.handleUniversalLinkInPasteboard()
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
            analytics.log(navigation: Analytics.Navigation.openShortcut, properties: [
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

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: ActiveWalletCoordinator, source: UrlSource) {
        handleUniversalLink(url: url, source: source)
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

    func importPaidSignedOrder(signedOrder: SignedOrder, token: Token, inViewController viewController: ImportMagicTokenViewController, completion: @escaping (Bool) -> Void) {
        activeWalletCoordinator?.importPaidSignedOrder(signedOrder: signedOrder, token: token, inViewController: viewController, completion: completion)
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

extension AppCoordinator: UniversalLinkServiceDelegate {

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
            let paymentFlowResolver = PaymentFlowFromEip681UrlResolver(tokensService: resolver.service, account: account, assetDefinitionStore: assetDefinitionStore, analytics: analytics, config: config)
            guard let promise = paymentFlowResolver.resolve(url: url) else { return }
            firstly {
                promise
            }.done { (paymentFlow: PaymentFlow, server: RPCServer) in
                resolver.showPaymentFlow(for: paymentFlow, server: server, navigationController: resolver.presentationNavigationController)
            }.cauterize()
        case .walletConnect(let url, let source):
            switch source {
            case .safariExtension:
                analytics.log(action: Analytics.Action.tapSafariExtensionRewrittenUrl, properties: [
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

            if let session = resolver.sessions[safe: server] {
                let coordinator = ImportMagicLinkCoordinator(
                    analytics: analytics,
                    session: session,
                    config: config,
                    assetDefinitionStore: assetDefinitionStore,
                    url: url,
                    keystore: keystore,
                    tokensService: resolver.service)

                coordinator.delegate = self
                let handled = coordinator.start(url: url)

                if handled {
                    addCoordinator(coordinator)
                }
            } else {
                let coordinator = ServerUnavailableCoordinator(navigationController: navigationController, servers: [server])
                coordinator.delegate = self
                addCoordinator(coordinator)
                coordinator.start()
            }
        case .walletApi(let action):
            walletApiCoordinator.handle(action: action)
        }
    }

    func resolve(for coordinator: UniversalLinkService) -> UrlSchemeResolver? {
        return activeWalletCoordinator
    }
}

extension AppCoordinator: ServerUnavailableCoordinatorDelegate {
    func didDismiss(in coordinator: ServerUnavailableCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension AppCoordinator: WalletApiCoordinatorDelegate {
    func didOpenUrl(in service: WalletApiCoordinator, redirectUrl: URL) {
        if UIApplication.shared.canOpenURL(redirectUrl) {
            UIApplication.shared.open(redirectUrl)
        } else if let coordinator = activeWalletCoordinator {
            coordinator.openURLInBrowser(url: redirectUrl)
        }
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

extension AppCoordinator: KeystoreDelegate {
    func didImport(wallet: Wallet, in keystore: Keystore) {
        PromptBackupCoordinator(keystore: keystore, wallet: wallet, config: config, analytics: analytics).markWalletAsImported()
    }
}
