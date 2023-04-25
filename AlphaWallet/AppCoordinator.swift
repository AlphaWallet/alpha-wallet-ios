// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import UIKit
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletTrackAPICalls

extension TokenScript {
    static let baseTokenScriptFiles: [TokenType: String] = [
        .erc20: (try! String(contentsOf: R.file.erc20TokenScriptTsml()!)),
        .erc721: (try! String(contentsOf: R.file.erc721TokenScriptTsml()!)),
    ]
}

// swiftlint:disable type_body_length
class AppCoordinator: NSObject, Coordinator {
    private let config = Config()
    private let legacyFileBasedKeystore: LegacyFileBasedKeystore
    private lazy var lock: Lock = SecuredLock(securedStorage: securedStorage)
    private var keystore: Keystore
    private lazy var assetDefinitionStore = AssetDefinitionStore(
        baseTokenScriptFiles: TokenScript.baseTokenScriptFiles,
        networkService: networkService,
        blockchainsProvider: blockchainsProvider)
    private let window: UIWindow
    private var appTracker = AppTracker()
    //TODO rename and replace type? Not Initializer but similar as of writing
    private var services: [Initializer] = []
    private var initialWalletCreationCoordinator: InitialWalletCreationCoordinator? {
        return coordinators.compactMap { $0 as? InitialWalletCreationCoordinator }.first
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

    private lazy var restartHandler: RestartQueueHandler = {
        return RestartQueueHandler(
            serversProvider: serversProvider,
            restartQueue: RestartTaskQueue())
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var activeWalletCoordinator: ActiveWalletCoordinator? {
        return coordinators.first { $0 is ActiveWalletCoordinator } as? ActiveWalletCoordinator
    }

    private lazy var currencyService = CurrencyService(storage: config)
    private lazy var coinTickersFetcher: CoinTickersFetcher = CoinTickersFetcherImpl(
        transporter: BaseApiTransporter(),
        analytics: analytics)
    
    private let dependencies: AtomicDictionary<Wallet, WalletDependencies> = .init()
    private lazy var walletBalanceService = MultiWalletBalanceService(currencyService: currencyService)
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
            domainResolutionService: domainResolutionService,
            promptBackup: promptBackup)

        coordinator.delegate = self

        return coordinator
    }()
    private lazy var networkService: NetworkService = BaseNetworkService(analytics: analytics)
    private lazy var tokenSwapper: TokenSwapper = {
        TokenSwapper(
            reachabilityManager: ReachabilityManager(),
            serversProvider: serversProvider,
            networking: LiQuestTokenSwapperNetworking(networkService: networkService),
            analyticsLogger: analytics)
    }()
    private lazy var tokenActionsService: TokenActionsService = {
        let service = TokenActionsService()
        service.register(service: BuyTokenProvider(subProviders: [
            Coinbase(action: R.string.localizable.aWalletTokenBuyOnCoinbaseTitle()),
            Ramp(action: R.string.localizable.aWalletTokenBuyOnRampTitle(), networkProvider: RampNetworkProvider(networkService: networkService))
        ], action: R.string.localizable.aWalletTokenBuyTitle()))

        let honeySwapService = HoneySwap(action: R.string.localizable.aWalletTokenErc20ExchangeHoneyswapButtonTitle())
        honeySwapService.theme = navigationController.traitCollection.honeyswapTheme

        let quickSwap = QuickSwap(action: R.string.localizable.aWalletTokenErc20ExchangeOnQuickSwapButtonTitle())
        quickSwap.theme = navigationController.traitCollection.uniswapTheme
        var availableSwapProviders: [SupportedTokenActionsProvider & TokenActionProvider] = [
            honeySwapService,
            quickSwap,
            Oneinch(action: R.string.localizable.aWalletTokenErc20ExchangeOn1inchButtonTitle(), networkProvider: OneinchNetworkProvider(networkService: networkService)),
            //uniswap
        ]
        availableSwapProviders += Features.default.isAvailable(.isSwapEnabled) ? [SwapTokenNativeProvider(tokenSwapper: tokenSwapper)] : []

        service.register(service: SwapTokenProvider(subProviders: availableSwapProviders, action: R.string.localizable.aWalletTokenSwapButtonTitle()))
        service.register(service: ArbitrumBridge(action: R.string.localizable.aWalletTokenArbitrumBridgeButtonTitle()))
        service.register(service: xDaiBridge(action: R.string.localizable.aWalletTokenXDaiBridgeButtonTitle()))

        return service
    }()
    private lazy var serversProvider: ServersProvidable = {
        BaseServersProvider(config: config)
    }()
    private lazy var caip10AccountProvidable: CAIP10AccountProvidable = {
        AnyCAIP10AccountProvidable(keystore: keystore, serversProvidable: serversProvider)
    }()

    private lazy var walletConnectProvider: WalletConnectProvider = {
        let provider = WalletConnectProvider(
            keystore: keystore,
            config: config,
            dependencies: dependencies)
        let decoder = WalletConnectRequestDecoder()

        let v1Provider = WalletConnectV1Provider(
            caip10AccountProvidable: caip10AccountProvidable,
            client: WalletConnectV1NativeClient(),
            storage: WalletConnectV1Storage(),
            decoder: decoder,
            config: config)

        let v2Provider = WalletConnectV2Provider(
            caip10AccountProvidable: caip10AccountProvidable,
            storage: WalletConnectV2Storage(),
            serversProvider: serversProvider,
            decoder: decoder,
            client: WalletConnectV2NativeClient())

        provider.register(service: v1Provider)
        provider.register(service: v2Provider)

        return provider
    }()

    private lazy var walletConnectCoordinator: WalletConnectCoordinator = {
        let coordinator = WalletConnectCoordinator(
            keystore: keystore,
            navigationController: navigationController,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            config: config,
            assetDefinitionStore: assetDefinitionStore,
            networkService: networkService,
            walletConnectProvider: walletConnectProvider,
            dependencies: dependencies,
            restartHandler: restartHandler,
            serversProvider: serversProvider)

        return coordinator
    }()
    private var cancelable = Set<AnyCancellable>()
    private let sharedEnsRecordsStorage: EnsRecordsStorage = {
        let storage: EnsRecordsStorage = RealmStore.shared
        return storage
    }()
    private lazy var blockchainProviderForResolvingEns: BlockchainProvider = RpcBlockchainProvider(server: .forResolvingEns, analytics: analytics, params: .defaultParams(for: .forResolvingEns))
    lazy private var blockiesGenerator: BlockiesGenerator = BlockiesGenerator(
        assetImageProvider: OpenSea(analytics: analytics, server: .main, config: config),
        storage: sharedEnsRecordsStorage,
        blockchainProvider: blockchainProviderForResolvingEns)

    lazy private var domainResolutionService: DomainResolutionServiceType = DomainResolutionService(
        blockiesGenerator: blockiesGenerator,
        storage: sharedEnsRecordsStorage,
        networkService: networkService,
        blockchainProvider: blockchainProviderForResolvingEns)

    private lazy var walletApiCoordinator: WalletApiCoordinator = {
        let coordinator = WalletApiCoordinator(
            keystore: keystore,
            navigationController: navigationController,
            analytics: analytics,
            config: config,
            restartHandler: restartHandler,
            networkService: networkService,
            serversProvider: serversProvider)

        coordinator.delegate = self

        return coordinator
    }()

    private lazy var notificationService: NotificationService = {
        let pushNotificationsService = UNUserNotificationsService()
        let notificationService = LocalNotificationService()

        return NotificationService(
            sources: [],
            walletBalanceService: walletBalanceService,
            notificationService: notificationService,
            pushNotificationsService: pushNotificationsService)
    }()

    private lazy var blockchainFactory: BlockchainFactory = {
        return BaseBlockchainFactory(
            config: config,
            analytics: analytics)
    }()

    private lazy var blockchainsProvider: BlockchainsProvider = {
        return BlockchainsProvider(
            serversProvider: serversProvider,
            blockchainFactory: blockchainFactory)
    }()
    private let reachability = ReachabilityManager()
    private let securedStorage: SecuredPasswordStorage & SecuredStorage
    private let addressStorage: FileAddressStorage
    private let tokenScriptOverridesFileManager = TokenScriptOverridesFileManager()
    private let apiTransporterFactory = ApiTransporterFactory()
    private lazy var tokenImageFetcher: TokenImageFetcher = TokenImageFetcherImpl(
        networking: KingfisherImageFetcher(),
        tokenGroupIdentifier: tokenGroupIdentifier,
        spamImage: R.image.spamSmall()!)

    private let tokenGroupIdentifier: TokenGroupIdentifierProtocol = TokenGroupIdentifier.identifier(tokenJsonUrl: R.file.tokensJson()!)!

    //Unfortunate to have to have a factory method and not be able to use an initializer (because we can't override `init()` to throw)
    static func create() throws -> AppCoordinator {
        crashlytics.register(AlphaWallet.FirebaseCrashlyticsReporter.instance)
        applyStyle()

        let window = UIWindow(frame: UIScreen.main.bounds)
        let analytics = AnalyticsService()
        let walletAddressesStore: WalletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .standardOrForTests)
        let securedStorage: SecuredStorage & SecuredPasswordStorage = try KeychainStorage()
        let legacyFileBasedKeystore = try LegacyFileBasedKeystore(securedStorage: securedStorage)

        let keystore: Keystore = EtherKeystore(
            keychain: securedStorage,
            walletAddressesStore: walletAddressesStore,
            analytics: analytics,
            legacyFileBasedKeystore: legacyFileBasedKeystore,
            hardwareWalletFactory: BCHardwareWalletCreator())

        let navigationController: UINavigationController = .withOverridenBarAppearence()
        navigationController.view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        let coordinator = AppCoordinator(
            window: window,
            analytics: analytics,
            keystore: keystore,
            navigationController: navigationController,
            securedStorage: securedStorage,
            legacyFileBasedKeystore: legacyFileBasedKeystore)

        return coordinator
    }

    init(window: UIWindow,
         analytics: AnalyticsServiceType,
         keystore: Keystore,
         navigationController: UINavigationController,
         securedStorage: SecuredPasswordStorage & SecuredStorage,
         legacyFileBasedKeystore: LegacyFileBasedKeystore) {

        let addressStorage = FileAddressStorage()
        register(addressStorage: addressStorage)

        self.addressStorage = addressStorage
        self.navigationController = navigationController
        self.window = window
        self.analytics = analytics
        self.keystore = keystore
        self.securedStorage = securedStorage
        self.legacyFileBasedKeystore = legacyFileBasedKeystore

        super.init()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        setupSplashViewController(on: navigationController)
        bindWalletAddressesStore()
    }
    private lazy var promptBackup = PromptBackup(
        keystore: keystore,
        config: config,
        analytics: analytics,
        walletBalanceProvidable: walletBalanceService)

    private func bindWalletAddressesStore() {
        keystore.didRemoveWallet
            .sink { [serversProvider, legacyFileBasedKeystore, promptBackup] account in

                //TODO: pass ref
                FileWalletStorage().addOrUpdate(name: nil, for: account.address)
                promptBackup.deleteWallet(wallet: account)
                //TODO: make same as WalletConfig
                TransactionsTracker.resetFetchingState(account: account, serversProvider: serversProvider)
                Erc1155TokenIdsFetcher.deleteForWallet(account.address)
                DatabaseMigration.addToDeleteList(address: account.address)
                legacyFileBasedKeystore.delete(wallet: account)
                WalletConfig(address: account.address).clear()
                self.destroy(for: account)
            }.store(in: &cancelable)

        keystore.didAddWallet
            .sink { [promptBackup] in
                switch $0.event {
                case .new, .watch, .hardware:
                    break
                case .keystore, .mnemonic, .privateKey:
                    promptBackup.markWalletAsImported(wallet: $0.wallet)
                }
            }.store(in: &cancelable)

        keystore.walletsPublisher
            .receive(on: RunLoop.main) //NOTE: async to avoid `swift_beginAccess` crash
            .map { wallets -> [Wallet: WalletBalanceFetcherType] in
                var fetchers: [Wallet: WalletBalanceFetcherType] = [:]

                for wallet in wallets {
                    let dep = self.buildDependencies(for: wallet)
                    fetchers[wallet] = dep.fetcher
                }

                return fetchers
            }.sink { [walletBalanceService] in walletBalanceService.start(fetchers: $0) }
            .store(in: &cancelable)
    }

    func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        if AlphaWallet.Device.isSimulator {
            //Want to start as soon as possible
            TrackApiCalls.shared.start()

            UserDefaults.standard.set(!isRunningTests(), forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        }

        if Features.default.isAvailable(.isLoggingEnabledForTickerMatches) {
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                infoLog("Ticker ID positive matching counts: \(TickerIdFilter.matchCounts)")
            }
        }

        blockchainsProvider.start()
        DatabaseMigration.dropDeletedRealmFiles(excluding: keystore.wallets)
        protectionCoordinator.didFinishLaunchingWithOptions()
        initializers()
        runServices()
        appTracker.start()
        notificationService.registerForReceivingRemoteNotifications()
        tokenScriptOverridesFileManager.start()
        migrateToStoringRawPrivateKeysInKeychain()
        tokenActionsService.start()

        addCoordinator(walletConnectCoordinator)

        if let wallet = keystore.currentWallet, keystore.hasWallets {
            showActiveWallet(for: wallet, animated: false)
        } else {
            showInitialWalletCoordinator()
        }

        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem, shortcutItem.type == Constants.launchShortcutKey {
            //Delay needed to work because app is launching..
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.launchUniversalScannerFromQuickAction()
            }
        }
    }

    deinit {
        tokenScriptOverridesFileManager.stop()
    }

    func applicationPerformActionFor(_ shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == Constants.launchShortcutKey {
            launchUniversalScannerFromQuickAction()
        }
        completionHandler(true)
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

    func applicationShouldAllowExtensionPointIdentifier(_ extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        if extensionPointIdentifier == .keyboard {
            return false
        }
        return true
    }

    func applicationOpenUrl(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return handleUniversalLink(url: url, source: .customUrlScheme)
    }

    func applicationContinueUserActivity(_ userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let hasHandledIntent = handleIntent(userActivity: userActivity)
        if hasHandledIntent {
            return true
        }

        var handled = false
        if let url = userActivity.webpageURL {
            handled = handleUniversalLink(url: url, source: .deeplink)
        }
        //TODO: if we handle other types of URLs, check if handled==false, then we pass the url to another handlers
        return handled
    }

    private func setupSplashViewController(on navigationController: UINavigationController) {
        navigationController.viewControllers = [
            SplashViewController()
        ]
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    private func migrateToStoringRawPrivateKeysInKeychain() {
        legacyFileBasedKeystore.migrateKeystoreFilesToRawPrivateKeysInKeychain(using: keystore)
    }

    @discardableResult func showActiveWallet(for wallet: Wallet, animated: Bool) -> ActiveWalletCoordinator {
        if let coordinator = initialWalletCreationCoordinator {
            removeCoordinator(coordinator)
        }

        let dep = buildDependencies(for: wallet)

        let coordinator = ActiveWalletCoordinator(
            navigationController: navigationController,
            activitiesPipeLine: dep.activitiesPipeLine,
            wallet: wallet,
            keystore: keystore,
            assetDefinitionStore: assetDefinitionStore,
            config: config,
            appTracker: appTracker,
            analytics: analytics,
            restartHandler: restartHandler,
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
            transactionsDataStore: dep.transactionsDataStore,
            tokensService: dep.tokensService,
            tokenGroupIdentifier: tokenGroupIdentifier,
            lock: lock,
            currencyService: currencyService,
            tokenScriptOverridesFileManager: tokenScriptOverridesFileManager,
            networkService: networkService,
            promptBackup: promptBackup,
            caip10AccountProvidable: caip10AccountProvidable,
            tokenImageFetcher: tokenImageFetcher,
            serversProvider: serversProvider)

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
            CleanupWallets(keystore: keystore, config: config),
            SkipBackupFiles(legacyFileBasedKeystore: legacyFileBasedKeystore),
            CleanupPasscode(keystore: keystore, lock: lock),
            KeyboardInitializer()
        ]

        initializers.forEach { $0.perform() }
    }

    private func runServices() {
        services = [
            ReportUsersWalletAddresses(keystore: keystore),
            ReportUsersActiveChains(serversProvider: serversProvider),
            MigrateToSupportEip1559Transactions(serversProvider: serversProvider, keychain: keystore)
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
        let coordinator = InitialWalletCreationCoordinator(
            config: config,
            navigationController: navigationController,
            keystore: keystore,
            analytics: analytics,
            domainResolutionService: domainResolutionService)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
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
    @discardableResult private func handleUniversalLink(url: URL, source: UrlSource) -> Bool {
        keystore.createWalletIfMissing()
            .sink(receiveValue: { _ in self.showActiveWalletIfNeeded() })
            .store(in: &cancelable)

        return universalLinkService.handleUniversalLink(url: url, source: source)
    }

    func handleUniversalLinkInPasteboard() {
        universalLinkService.handleUniversalLinkInPasteboard()
    }

    private func launchUniversalScannerFromQuickAction() {
        launchUniversalScanner(fromSource: .quickAction)
    }

    private func launchUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        showActiveWalletIfNeeded()
        activeWalletCoordinator?.launchUniversalScanner(fromSource: source)
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

    private func handleIntent(userActivity: NSUserActivity) -> Bool {
        if let type = userActivity.userInfo?[Donations.typeKey] as? String {
            infoLog("[Shortcuts] handleIntent type: \(type)")
            if type == CameraDonation.userInfoTypeValue {
                analytics.log(navigation: Analytics.Navigation.openShortcut, properties: [
                    Analytics.Properties.type.rawValue: Analytics.ShortcutType.camera.rawValue
                ])
                self.launchUniversalScanner(fromSource: .siriShortcut)
                return true
            }
            if type == WalletQrCodeDonation.userInfoTypeValue {
                analytics.log(navigation: Analytics.Navigation.openShortcut, properties: [
                    Analytics.Properties.type.rawValue: Analytics.ShortcutType.walletQrCode.rawValue
                ])
                activeWalletCoordinator?.showWalletQrCode()
                return true
            }
        }
        return false
    }

    private func buildDependencies(for wallet: Wallet) -> WalletDependencies {
        if let dep = dependencies[wallet] { return dep  }

        let tokensDataStore: TokensDataStore = MultipleChainsTokensDataStore(store: .storage(for: wallet))
        let eventsDataStore: NonActivityEventsDataStore = NonActivityMultiChainEventsDataStore(store: .storage(for: wallet))
        let transactionsDataStore: TransactionDataStore = TransactionDataStore(store: .storage(for: wallet))
        let eventsActivityDataStore: EventsActivityDataStoreProtocol = EventsActivityDataStore(store: .storage(for: wallet))

        let sessionsProvider = BaseSessionsProvider(
            config: config,
            analytics: analytics,
            blockchainsProvider: blockchainsProvider,
            tokensDataStore: tokensDataStore,
            eventsDataStore: eventsDataStore,
            assetDefinitionStore: assetDefinitionStore,
            reachability: reachability,
            wallet: wallet,
            apiTransporterFactory: apiTransporterFactory)

        sessionsProvider.start()

        let tokensService = AlphaWalletTokensService(
            sessionsProvider: sessionsProvider,
            tokensDataStore: tokensDataStore,
            analytics: analytics,
            transactionsStorage: transactionsDataStore,
            assetDefinitionStore: assetDefinitionStore,
            transporter: BaseApiTransporter())

        let tokensPipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(
            wallet: wallet,
            tokensService: tokensService,
            coinTickersFetcher: coinTickersFetcher,
            assetDefinitionStore: assetDefinitionStore,
            eventsDataStore: eventsDataStore,
            currencyService: currencyService,
            sessionsProvider: sessionsProvider)

        tokensPipeline.start()

        let fetcher = WalletBalanceFetcher(
            wallet: wallet,
            tokensPipeline: tokensPipeline,
            currencyService: currencyService,
            tokensService: tokensService)

        fetcher.start()

        let activitiesPipeLine = ActivitiesPipeLine(
            config: config,
            wallet: wallet,
            assetDefinitionStore: assetDefinitionStore,
            transactionDataStore: transactionsDataStore,
            tokensService: tokensService,
            sessionsProvider: sessionsProvider,
            eventsActivityDataStore: eventsActivityDataStore,
            eventsDataStore: eventsDataStore)

        let dependency = WalletDependencies(
            activitiesPipeLine: activitiesPipeLine,
            transactionsDataStore: transactionsDataStore,
            tokensDataStore: tokensDataStore,
            tokensService: tokensService,
            pipeline: tokensPipeline,
            fetcher: fetcher,
            sessionsProvider: sessionsProvider,
            eventsDataStore: eventsDataStore,
            currencyService: currencyService,
            coinTickersFetcher: coinTickersFetcher)

        dependencies[wallet] = dependency

        return dependency
    }

    private func destroy(for wallet: Wallet) {
        dependencies.removeValue(forKey: wallet)
    }
}
// swiftlint:enable type_body_length

extension AppCoordinator: InitialWalletCreationCoordinatorDelegate {

    func didCancel(in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didAddAccount(_ wallet: Wallet, in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)

        removeCoordinator(coordinator)
        showActiveWallet(for: wallet, animated: false)
    }

}

extension AppCoordinator: ActiveWalletCoordinatorDelegate {

    func didRestart(in coordinator: ActiveWalletCoordinator, reason: RestartReason, wallet: Wallet) {
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

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: ActiveWalletCoordinator, source: UrlSource) {
        handleUniversalLink(url: url, source: source)
    }
}

extension AppCoordinator: ImportMagicLinkCoordinatorDelegate {

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        activeWalletCoordinator?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: source)
    }

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

    func didClose(in coordinator: ImportMagicLinkCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension AppCoordinator: UniversalLinkServiceDelegate {

    private var hasImportMagicLinkCoordinator: ImportMagicLinkCoordinator? {
        return coordinators.compactMap { $0 as? ImportMagicLinkCoordinator }.first
    }

    func handle(url: DeepLink, for resolver: UrlSchemeResolver) {
        switch url {
        case .maybeFileUrl(let url):
            tokenScriptOverridesFileManager.importTokenScriptOverrides(url: url)
        case .eip681(let url):
            guard let wallet = keystore.currentWallet, let dependency = dependencies[wallet] else { return }

            let paymentFlowResolver = Eip681UrlResolver(
                sessionsProvider: dependency.sessionsProvider,
                missingRPCServerStrategy: .fallbackToAnyMatching)

            paymentFlowResolver.resolve(url: url)
                .sinkAsync(receiveCompletion: { result in
                    guard case .failure(let error) = result else { return }
                    verboseLog("[Eip681UrlResolver] failure to resolve value from: \(url) with error: \(error)")
                }, receiveValue: { result in
                    switch result {
                    case .address:
                        break //Add handling address, maybe same action when scan qr code
                    case .transaction(let transactionType, let token):
                        resolver.showPaymentFlow(for: .send(type: .transaction(transactionType)), server: token.server, navigationController: resolver.presentationNavigationController)
                    }
                })
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
            guard let wallet = keystore.currentWallet, let dependency = dependencies[wallet], hasImportMagicLinkCoordinator == nil else { return }

            if let session = dependency.sessionsProvider.session(for: server) {
                let coordinator = ImportMagicLinkCoordinator(
                    analytics: analytics,
                    session: session,
                    config: config,
                    assetDefinitionStore: assetDefinitionStore,
                    keystore: keystore,
                    tokensService: dependency.pipeline,
                    networkService: networkService,
                    domainResolutionService: domainResolutionService,
                    importToken: session.importToken,
                    reachability: reachability)

                coordinator.delegate = self
                let handled = coordinator.start(url: url)

                if handled {
                    addCoordinator(coordinator)
                }
            } else {
                let coordinator = ServerUnavailableCoordinator(
                    navigationController: navigationController,
                    disabledServers: [server],
                    restartHandler: restartHandler)

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
    func didDismiss(in coordinator: ServerUnavailableCoordinator, result: Swift.Result<Void, Error>) {
        removeCoordinator(coordinator)
        //TODO: update to retry operation again after enabling disabled servers
    }
}

extension AppCoordinator {
    struct WalletDependencies {
        let activitiesPipeLine: ActivitiesPipeLine
        let transactionsDataStore: TransactionDataStore
        let tokensDataStore: TokensDataStore
        let tokensService: TokensService
        let pipeline: TokensProcessingPipeline
        let fetcher: WalletBalanceFetcher
        let sessionsProvider: SessionsProvider
        let eventsDataStore: NonActivityEventsDataStore
        let currencyService: CurrencyService
        let coinTickersFetcher: CoinTickersFetcher
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

    func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
    }

    func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        if keystore.wallets.isEmpty {
            //TODO not good to reach in and `hideLoading()` here
            coordinator.navigationController.hideLoading()
            showInitialWalletCoordinator()
        } else {
            //no-op
        }
    }

    func didCancel(in coordinator: AccountsCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
    }

    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        //NOTE: Push existing view controller to the app navigation stack
        if let pendingCoordinator = pendingActiveWalletCoordinator, keystore.currentWallet == account {
            addCoordinator(pendingCoordinator)

            pendingCoordinator.showTabBar(animated: true)
        } else {
            showActiveWallet(for: account, animated: true)
        }

        pendingActiveWalletCoordinator = .none
    }
}
