import UIKit
import BigInt
import PromiseKit
import RealmSwift
import Result

// swiftlint:disable file_length
protocol InCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: InCoordinator)
    func didUpdateAccounts(in coordinator: InCoordinator)
    func didShowWallet(in coordinator: InCoordinator)
    func assetDefinitionsOverrideViewController(for coordinator: InCoordinator) -> UIViewController?
    func importUniversalLink(url: URL, forCoordinator coordinator: InCoordinator)
    func handleUniversalLink(_ url: URL, forCoordinator coordinator: InCoordinator)
    func handleCustomUrlScheme(_ url: URL, forCoordinator coordinator: InCoordinator)
    func showWallets(in coordinator: InCoordinator)
    func didRestart(in coordinator: InCoordinator, wallet: Wallet)
}

enum Tabs {
    case wallet
    case alphaWalletSettings
    case transactionsOrActivity
    case browser

    var className: String {
        switch self {
        case .wallet:
            return String(describing: TokensViewController.self)
        case .transactionsOrActivity:
            if Features.isActivityEnabled {
                return String(describing: ActivitiesViewController.self)
            } else {
                return String(describing: TransactionsViewController.self)
            }
        case .alphaWalletSettings:
            return String(describing: SettingsViewController.self)
        case .browser:
            return String(describing: DappsHomeViewController.self)
        }
    }
}

// swiftlint:disable type_body_length
class InCoordinator: NSObject, Coordinator {
    private var wallet: Wallet
    private let config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    private let appTracker: AppTracker
    private var transactionsStorages = ServerDictionary<TransactionsStorage>()
    private var walletSessions = ServerDictionary<WalletSession>()
    private let analyticsCoordinator: AnalyticsCoordinator
    private let restartQueue: RestartTaskQueue
    private var callForAssetAttributeCoordinators = ServerDictionary<CallForAssetAttributeCoordinator>() {
        didSet {
            XMLHandler.callForAssetAttributeCoordinators = callForAssetAttributeCoordinators
        }
    }
    private let queue: DispatchQueue = DispatchQueue(label: "com.Background.updateQueue", qos: .userInitiated)
    //TODO rename this generic name to reflect that it's for event instances, not for event activity
    lazy private var eventsDataStore: EventsDataStore = EventsDataStore(realm: realm)
    lazy private var eventsActivityDataStore: EventsActivityDataStore = EventsActivityDataStore(realm: realm, queue: queue)
    private var eventSourceCoordinatorForActivities: EventSourceCoordinatorForActivities?
    private let coinTickersFetcher: CoinTickersFetcherType
    private lazy var eventSourceCoordinator: EventSourceCoordinatorType = createEventSourceCoordinator()
    var tokensStorages = ServerDictionary<TokensDataStore>()
    private var claimOrderCoordinatorCompletionBlock: ((Bool) -> Void)?

    lazy var nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>> = {
        return createEtherPricesSubscribablesForAllChains()
    }()
    lazy var nativeCryptoCurrencyBalances: ServerDictionary<Subscribable<BigInt>> = {
        return createEtherBalancesSubscribablesForAllChains()
    }()
    private var transactionCoordinator: TransactionCoordinator? {
        return coordinators.compactMap { $0 as? TransactionCoordinator }.first
    }
    private var tokensCoordinator: TokensCoordinator? {
        return coordinators.compactMap { $0 as? TokensCoordinator }.first
    }
    var dappBrowserCoordinator: DappBrowserCoordinator? {
        coordinators.compactMap { $0 as? DappBrowserCoordinator }.first
    }
    private var activityCoordinator: ActivitiesCoordinator? {
        return coordinators.compactMap { $0 as? ActivitiesCoordinator }.first
    }

    private lazy var helpUsCoordinator: HelpUsCoordinator = {
        HelpUsCoordinator(navigationController: navigationController, appTracker: appTracker, analyticsCoordinator: analyticsCoordinator)
    }()

    private lazy var whatsNewExperimentCoordinator: WhatsNewExperimentCoordinator = {
        let coordinator = WhatsNewExperimentCoordinator(navigationController: navigationController, userDefaults: UserDefaults.standard, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        return coordinator
    }()

    lazy var filterTokensCoordinator: FilterTokensCoordinator = {
        return .init(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService, coinTickersFetcher: coinTickersFetcher)
    }()

    private lazy var activitiesService: ActivitiesServiceType = createActivitiesService()
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var keystore: Keystore
    var urlSchemeCoordinator: UrlSchemeCoordinatorType
    weak var delegate: InCoordinatorDelegate?

    private let walletBalanceCoordinator: WalletBalanceCoordinatorType

    private lazy var realm = Wallet.functional.realm(forAccount: wallet)
    private lazy var oneInchSwapService = Oneinch()
    private lazy var rampBuyService = Ramp(account: wallet)
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

    private lazy var walletConnectCoordinator: WalletConnectCoordinator = createWalletConnectCoordinator()

    private let promptBackupCoordinator: PromptBackupCoordinator

    lazy var tabBarController: UITabBarController = {
        let tabBarController = TabBarController()
        tabBarController.tabBar.isTranslucent = false
        tabBarController.delegate = self

        return tabBarController
    }()
    private let accountsCoordinator: AccountsCoordinator

    init(
            navigationController: UINavigationController = UINavigationController(),
            wallet: Wallet,
            keystore: Keystore,
            assetDefinitionStore: AssetDefinitionStore,
            config: Config,
            appTracker: AppTracker = AppTracker(),
            analyticsCoordinator: AnalyticsCoordinator,
            restartQueue: RestartTaskQueue,
            urlSchemeCoordinator: UrlSchemeCoordinatorType,
            promptBackupCoordinator: PromptBackupCoordinator,
            accountsCoordinator: AccountsCoordinator,
            walletBalanceCoordinator: WalletBalanceCoordinatorType,
            coinTickersFetcher: CoinTickersFetcherType
    ) {
        self.navigationController = navigationController
        self.wallet = wallet
        self.keystore = keystore
        self.config = config
        self.appTracker = appTracker
        self.analyticsCoordinator = analyticsCoordinator
        self.restartQueue = restartQueue
        self.assetDefinitionStore = assetDefinitionStore
        self.urlSchemeCoordinator = urlSchemeCoordinator
        self.promptBackupCoordinator = promptBackupCoordinator
        self.accountsCoordinator = accountsCoordinator
        self.walletBalanceCoordinator = walletBalanceCoordinator
        self.coinTickersFetcher = coinTickersFetcher
        //Disabled for now. Refer to function's comment
        //self.assetDefinitionStore.enableFetchXMLForContractInPasteboard()
        super.init()
    }

    deinit {
        XMLHandler.callForAssetAttributeCoordinators = nil
        //NOTE: Clear all smart contract calls
        clearSmartContractCallsCache()
    }

    func start(animated: Bool) {
        donateWalletShortcut()

        showTabBar(for: wallet, animated: animated)
        checkDevice()

        helpUsCoordinator.start()
        addCoordinator(helpUsCoordinator)
        fetchXMLAssetDefinitions()
        listOfBadTokenScriptFilesChanged(fileNames: assetDefinitionStore.listOfBadTokenScriptFiles + assetDefinitionStore.conflictingTokenScriptFileNames.all)
        setupWatchingTokenScriptFileChangesToFetchEvents()

        urlSchemeCoordinator.processPendingURL(in: self)
        oneInchSwapService.fetchSupportedTokens()
        rampBuyService.fetchSupportedTokens()

        processRestartQueueAfterRestart(config: config, coordinator: self, restartQueue: restartQueue)

        showWhatsNew()
    }

    private func showWhatsNew() {
        whatsNewExperimentCoordinator.start()
        addCoordinator(whatsNewExperimentCoordinator)
    }

    private func donateWalletShortcut() {
        WalletQrCodeDonation(address: wallet.address).donate()
    }

    func launchUniversalScanner() {
        tokensCoordinator?.launchUniversalScanner(fromSource: .quickAction)
    }

    private func createActivitiesService() -> ActivitiesServiceType {
        return ActivitiesService(config: config, sessions: walletSessions, assetDefinitionStore: assetDefinitionStore, eventsActivityDataStore: eventsActivityDataStore, eventsDataStore: eventsDataStore, transactionCollection: transactionsCollection, queue: queue, tokensCollection: tokenCollection)
    }

    private func setupWatchingTokenScriptFileChangesToFetchEvents() {
        //TODO this is firing twice for each contract. We can be more efficient
        assetDefinitionStore.subscribeToBodyChanges { [weak self] contract in
            guard let strongSelf = self else { return }
            strongSelf.tokenCollection.tokenObjectPromise(forContract: contract).done { tokenObject in
                //Assume same contract don't exist in multiple chains
                guard let token = tokenObject else { return }
                let xmlHandler = XMLHandler(token: token, assetDefinitionStore: strongSelf.assetDefinitionStore)
                guard xmlHandler.hasAssetDefinition, let server = xmlHandler.server else { return }
                switch server {
                case .any:
                    for each in strongSelf.config.enabledServers {
                        strongSelf.fetchEvents(forTokenContract: contract, server: each)
                    }
                case .server(let server):
                    strongSelf.fetchEvents(forTokenContract: contract, server: server)
                }
            }.cauterize()
        }
    }

    private func fetchEvents(forTokenContract contract: AlphaWallet.Address, server: RPCServer) {
        let tokensDataStore = tokensStorages[server]
        guard let token = tokensDataStore.token(forContract: contract) else { return }
        eventsDataStore.deleteEvents(forTokenContract: contract)
        let _ = eventSourceCoordinator.fetchEventsByTokenId(forToken: token)
        if Features.isActivityEnabled {
            let _ = eventSourceCoordinatorForActivities?.fetchEvents(forToken: token)
        }
    }

    private func createTokensDatastore(forConfig config: Config, server: RPCServer) -> TokensDataStore {
        let storage = walletBalanceCoordinator.tokensDatastore(wallet: wallet, server: server)
        return storage
    }

    private func createTransactionsStorage(server: RPCServer) -> TransactionsStorage {
        let storage = walletBalanceCoordinator.transactionsStorage(wallet: wallet, server: server)
        storage.delegate = self

        return storage
    }

    private func oneTimeCreationOfOneDatabaseToHoldAllChains() {
        let migration = MigrationInitializer(account: wallet)
        migration.oneTimeCreationOfOneDatabaseToHoldAllChains(assetDefinitionStore: assetDefinitionStore)
    }

    private func setupCallForAssetAttributeCoordinators() {
        callForAssetAttributeCoordinators = .init()
        for each in config.enabledServers {
            callForAssetAttributeCoordinators[each] = CallForAssetAttributeCoordinator(server: each, assetDefinitionStore: self.assetDefinitionStore)
        }
    }

    private func createEventSourceCoordinator() -> EventSourceCoordinatorType {
        return EventSourceCoordinator(wallet: wallet, tokenCollection: tokenCollection, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
    }

    private func setUpEventSourceCoordinatorForActivities() {
        guard Features.isActivityEnabled else { return }
        eventSourceCoordinatorForActivities = EventSourceCoordinatorForActivities(wallet: wallet, config: config, tokenCollection: tokenCollection, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsActivityDataStore)
    }

    private func setupTokenDataStores() {
        tokensStorages = .init()
        for each in config.enabledServers {
            let tokensStorage = createTokensDatastore(forConfig: config, server: each)
            tokensStorages[each] = tokensStorage
        }
    }

    private func setupTransactionsStorages() {
        transactionsStorages = .init()
        for each in config.enabledServers {
            let transactionsStorage = createTransactionsStorage(server: each)
            //TODO why do we remove such transactions? especially `.failed` and `.unknown`?
            transactionsStorage.removeTransactions(for: [.failed, .pending, .unknown])
            transactionsStorages[each] = transactionsStorage
        }
    }

    private func setupWalletSessions() {
        walletSessions = .init()
        for each in config.enabledServers {
            let balanceCoordinator = BalanceCoordinator(wallet: wallet, server: each, walletBalanceCoordinator: walletBalanceCoordinator)
            let session = WalletSession(account: wallet, server: each, config: config, balanceCoordinator: balanceCoordinator)

            walletSessions[each] = session
        }
    }
    private lazy var transactionsCollection: TransactionCollection = createTransactionsCollection()

    //Setup functions has to be called in the right order as they may rely on eg. wallet sessions being available. Wrong order should be immediately apparent with crash on startup. So don't worry
    private func setupResourcesOnMultiChain() {
        oneTimeCreationOfOneDatabaseToHoldAllChains()
        setupTokenDataStores()
        setupWalletSessions()
        setupNativeCryptoCurrencyPrices()
        setupNativeCryptoCurrencyBalances()
        setupTransactionsStorages()
        setupCallForAssetAttributeCoordinators()
        //TODO rename this generic name to reflect that it's for event instances, not for event activity. A few other related ones too
        eventSourceCoordinator = createEventSourceCoordinator()
        setUpEventSourceCoordinatorForActivities()
    }

    private func createTransactionsCollection() -> TransactionCollection {
        let transactionsStoragesForEnabledServers = config.enabledServers.map { transactionsStorages[$0] }
        return TransactionCollection(transactionsStorages: transactionsStoragesForEnabledServers, queue: queue)
    }

    private func setupNativeCryptoCurrencyPrices() {
        nativeCryptoCurrencyPrices = createEtherPricesSubscribablesForAllChains()
    }

    private func setupNativeCryptoCurrencyBalances() {
        nativeCryptoCurrencyBalances = createEtherBalancesSubscribablesForAllChains()
    }

    private func fetchEthereumEvents() {
        eventSourceCoordinator.fetchEthereumEvents()
        if Features.isActivityEnabled {
            eventSourceCoordinatorForActivities?.fetchEthereumEvents()
        }
    }

    private func pollEthereumEvents(tokenCollection: TokenCollection) {
        tokenCollection.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.fetchEthereumEvents()
        }
    }

    func showTabBar(for account: Wallet, animated: Bool) {
        keystore.recentlyUsedWallet = account
        rampBuyService.account = account
        wallet = account
        setupResourcesOnMultiChain()
        walletConnectCoordinator = createWalletConnectCoordinator()
        fetchEthereumEvents()

        setupTabBarController()

        showTabBar(animated: animated)
    }

    func showTabBar(animated: Bool) {
        navigationController.setViewControllers([accountsCoordinator.accountsViewController], animated: false)
        navigationController.pushViewController(tabBarController, animated: animated)

        navigationController.setNavigationBarHidden(true, animated: true)

        let inCoordinatorViewModel = InCoordinatorViewModel()
        showTab(inCoordinatorViewModel.initialTab)

        logEnabledChains()
        logWallets()
        logDynamicTypeSetting()
        promptBackupCoordinator.start()
    }

    private lazy var tokenCollection: TokenCollection = {
        let tokensStoragesForEnabledServers = config.enabledServers.map { tokensStorages[$0] }
        let tokenCollection = TokenCollection(filterTokensCoordinator: filterTokensCoordinator, tokenDataStores: tokensStoragesForEnabledServers)
        return tokenCollection
    }()

    private func createTokensCoordinator(promptBackupCoordinator: PromptBackupCoordinator, activitiesService: ActivitiesServiceType) -> TokensCoordinator {
        promptBackupCoordinator.listenToNativeCryptoCurrencyBalance(withWalletSessions: walletSessions)
        pollEthereumEvents(tokenCollection: tokenCollection)

        let coordinator = TokensCoordinator(
                sessions: walletSessions,
                keystore: keystore,
                config: config,
                tokenCollection: tokenCollection,
                nativeCryptoCurrencyPrices: nativeCryptoCurrencyPrices,
                assetDefinitionStore: assetDefinitionStore,
                eventsDataStore: eventsDataStore,
                promptBackupCoordinator: promptBackupCoordinator,
                filterTokensCoordinator: filterTokensCoordinator,
                analyticsCoordinator: analyticsCoordinator,
                tokenActionsService: tokenActionsService,
                walletConnectCoordinator: walletConnectCoordinator,
                transactionsStorages: transactionsStorages,
                coinTickersFetcher: coinTickersFetcher,
                activitiesService: activitiesService,
                walletBalanceCoordinator: walletBalanceCoordinator
        )

        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet(), selectedImage: nil)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createTransactionCoordinator(promptBackupCoordinator: PromptBackupCoordinator, transactionsCollection: TransactionCollection) -> TransactionCoordinator {
        let transactionDataCoordinator = TransactionDataCoordinator(
            sessions: walletSessions,
            transactionCollection: transactionsCollection,
            keystore: keystore,
            tokensStorages: tokensStorages,
            promptBackupCoordinator: promptBackupCoordinator
        )

        let coordinator = TransactionCoordinator(
                analyticsCoordinator: analyticsCoordinator,
                sessions: walletSessions,
                transactionsCollection: transactionsCollection,
                dataCoordinator: transactionDataCoordinator
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.transactionsTabbarItemTitle(), image: R.image.tab_transactions(), selectedImage: nil)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createActivityCoordinator(activitiesService: ActivitiesServiceType) -> ActivitiesCoordinator {
        let coordinator = ActivitiesCoordinator(analyticsCoordinator: analyticsCoordinator, sessions: walletSessions, tokensStorages: tokensStorages, assetDefinitionStore: assetDefinitionStore, activitiesService: activitiesService)
        coordinator.delegate = self
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.activityTabbarItemTitle(), image: R.image.tab_transactions(), selectedImage: nil)
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createBrowserCoordinator(sessions: ServerDictionary<WalletSession>, browserOnly: Bool, analyticsCoordinator: AnalyticsCoordinator) -> DappBrowserCoordinator {
        let coordinator = DappBrowserCoordinator(sessions: sessions, keystore: keystore, config: config, sharedRealm: realm, browserOnly: browserOnly, nativeCryptoCurrencyPrices: nativeCryptoCurrencyPrices, restartQueue: restartQueue, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        coordinator.start()
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.browserTabbarItemTitle(), image: R.image.tab_browser(), selectedImage: nil)
        addCoordinator(coordinator)
        return coordinator
    }

    private func createSettingsCoordinator(keystore: Keystore, promptBackupCoordinator: PromptBackupCoordinator) -> SettingsCoordinator {
        let coordinator = SettingsCoordinator(
                keystore: keystore,
                config: config,
                sessions: walletSessions,
                restartQueue: restartQueue,
                promptBackupCoordinator: promptBackupCoordinator,
                analyticsCoordinator: analyticsCoordinator,
            walletConnectCoordinator: walletConnectCoordinator,
            walletBalanceCoordinator: walletBalanceCoordinator
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.aSettingsNavigationTitle(), image: R.image.tab_settings(), selectedImage: nil)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    //TODO do we need 2 separate TokensDataStore instances? Is it because they have different delegates?
    private func setupTabBarController() {
        var viewControllers = [UIViewController]()

        let tokensCoordinator = createTokensCoordinator(promptBackupCoordinator: promptBackupCoordinator, activitiesService: activitiesService)

        configureNavigationControllerForLargeTitles(tokensCoordinator.navigationController)
        viewControllers.append(tokensCoordinator.navigationController)

        let transactionCoordinator = createTransactionCoordinator(promptBackupCoordinator: promptBackupCoordinator, transactionsCollection: transactionsCollection)
        configureNavigationControllerForLargeTitles(transactionCoordinator.navigationController)

        if Features.isActivityEnabled {
            let activityCoordinator = createActivityCoordinator(activitiesService: activitiesService)
            configureNavigationControllerForLargeTitles(activityCoordinator.navigationController)
            viewControllers.append(activityCoordinator.navigationController)
        } else {
            viewControllers.append(transactionCoordinator.navigationController)
        }

        let browserCoordinator = createBrowserCoordinator(sessions: walletSessions, browserOnly: false, analyticsCoordinator: analyticsCoordinator)
        viewControllers.append(browserCoordinator.navigationController)

        let settingsCoordinator = createSettingsCoordinator(keystore: keystore, promptBackupCoordinator: promptBackupCoordinator)
        configureNavigationControllerForLargeTitles(settingsCoordinator.navigationController)
        viewControllers.append(settingsCoordinator.navigationController)

        tabBarController.viewControllers = viewControllers
    }

    private func configureNavigationControllerForLargeTitles(_ navigationController: UINavigationController) {
        navigationController.navigationBar.prefersLargeTitles = true
        //When we enable large titles,
        //1. we can't get `UINavigationBar.appearance().setBackgroundImage(UIImage(color: Colors.appBackground), for: .default)` to work anymore, needing to replace it with: `UINavigationBar.appearance().barTintColor = Colors.appBackground`.
        //2. Without the former, we need to clear `isTranslucent` in order for view controllers that do not embed scroll views to clip off content at the top (unless we offset ourselves).
        //3. And when we clear `isTranslucent`, we need to set the navigationController's background ourselves, otherwise when pushing a view controller, the navigationController will show as black
        navigationController.navigationBar.isTranslucent = false
        navigationController.view.backgroundColor = Colors.appBackground
    }

    @objc private func dismissTransactions() {
        navigationController.dismiss(animated: true)
    }

    func showTab(_ selectTab: Tabs) {
        guard let viewControllers = tabBarController.viewControllers else {
            return
        }

        for controller in viewControllers {
            if let nav = controller as? UINavigationController {
                if nav.viewControllers[0].className == selectTab.className {
                    tabBarController.selectedViewController = nav
                    loadHomePageIfEmpty()
                }
            }
        }
    }

    private func disconnectWalletConnectSessionsSelectively(for reason: RestartReason) {
        switch reason {
        case .changeLocalization:
            break //no op
        case .serverChange:
            walletConnectCoordinator.disconnect(sessionsToDisconnect: .allExcept(config.enabledServers))
        case .walletChange:
            walletConnectCoordinator.disconnect(sessionsToDisconnect: .all)
        }
    }

    private func removeAllCoordinators() {
        coordinators.removeAll()
    }

    private func checkDevice() {
        let deviceChecker = CheckDeviceCoordinator(
                navigationController: navigationController,
                jailbreakChecker: DeviceChecker()
        )

        deviceChecker.start()

        addCoordinator(deviceChecker)
    }

    func showPaymentFlow(for type: PaymentFlow, server: RPCServer, navigationController: UINavigationController) {
        switch (type, walletSessions[server].account.type) {
        case (.send, .real), (.request, _):
            let coordinator = PaymentCoordinator(
                    navigationController: navigationController,
                    flow: type,
                    session: walletSessions[server],
                    keystore: keystore,
                    tokensStorage: tokensStorages[server],
                    ethPrice: nativeCryptoCurrencyPrices[server],
                    assetDefinitionStore: assetDefinitionStore,
                    analyticsCoordinator: analyticsCoordinator,
                    eventsDataStore: eventsDataStore
            )
            coordinator.delegate = self
            coordinator.start()

            addCoordinator(coordinator)
        case (_, _):
            if let topVC = navigationController.presentedViewController {
                topVC.displayError(error: InCoordinatorError.onlyWatchAccount)
            } else {
                navigationController.displayError(error: InCoordinatorError.onlyWatchAccount)
            }
        }
    }

    private func handlePendingTransaction(transaction: SentTransaction) {
        transactionCoordinator?.addSentTransaction(transaction)
    }

    private func showTransactionSent(transaction: SentTransaction) {
        UIAlertController.showTransactionSent(transaction: transaction, on: presentationViewController)
    }

    private func fetchXMLAssetDefinitions() {
        let coordinator = FetchAssetDefinitionsCoordinator(assetDefinitionStore: assetDefinitionStore, tokensDataStores: tokensStorages)
        coordinator.start()
        addCoordinator(coordinator)
    }

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, inViewController viewController: ImportMagicTokenViewController, completion: @escaping (Bool) -> Void) {
        guard let navigationController = viewController.navigationController else { return }
        let session = walletSessions[tokenObject.server]
        claimOrderCoordinatorCompletionBlock = completion
        let coordinator = ClaimPaidOrderCoordinator(navigationController: navigationController, keystore: keystore, session: session, tokenObject: tokenObject, signedOrder: signedOrder, ethPrice: nativeCryptoCurrencyPrices[session.server], analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func addImported(contract: AlphaWallet.Address, forServer server: RPCServer) {
        //Useful to check because we are/might action-only TokenScripts for native crypto currency
        guard !contract.sameContract(as: Constants.nativeCryptoAddressInDatabase) else { return }
        let tokensCoordinator = coordinators.first { $0 is TokensCoordinator } as? TokensCoordinator
        tokensCoordinator?.addImportedToken(forContract: contract, server: server)
    }

    private func createEtherPricesSubscribablesForAllChains() -> ServerDictionary<Subscribable<Double>> {
        var result = ServerDictionary<Subscribable<Double>>()
        for each in config.enabledServers {
            result[each] = createNativeCryptoCurrencyPriceSubscribable(forServer: each)
        }
        return result
    }

    private func createNativeCryptoCurrencyPriceSubscribable(forServer server: RPCServer) -> Subscribable<Double> {
        let etherToken = TokensDataStore.etherToken(forServer: server).addressAndRPCServer
        let subscription = walletSessions[server].balanceCoordinator.subscribableTokenBalance(etherToken)
        return subscription.map({ viewModel -> Double? in
            return viewModel.ticker?.price_usd
        }, on: .main)
    }

    private func createEtherBalancesSubscribablesForAllChains() -> ServerDictionary<Subscribable<BigInt>> {
        var result = ServerDictionary<Subscribable<BigInt>>()
        for each in config.enabledServers {
            result[each] = createCryptoCurrencyBalanceSubscribable(forServer: each)
        }
        return result
    }

    private func createCryptoCurrencyBalanceSubscribable(forServer server: RPCServer) -> Subscribable<BigInt> {
        let subscription = walletSessions[server].balanceCoordinator.subscribableEthBalanceViewModel
        return subscription.map({ viewModel -> BigInt? in
            return viewModel.value
        }, on: .main)
    }

    private func isViewControllerDappBrowserTab(_ viewController: UIViewController) -> Bool {
        guard let dappBrowserCoordinator = dappBrowserCoordinator else { return false }
        return dappBrowserCoordinator.rootViewController.navigationController == viewController
    }

    func show(error: Error) {
        //TODO Not comprehensive. Example, if we are showing a token instance view and tap on unverified to open browser, this wouldn't owrk
        if let topVC = navigationController.presentedViewController {
            topVC.displayError(error: error)
        } else {
            navigationController.displayError(error: error)
        }
    }

    func show(openedURL filename: String) {
        let controller = UIAlertController(title: nil, message: "\(filename) file imported with no error", preferredStyle: .alert)
        controller.popoverPresentationController?.sourceView = presentationViewController.view
        controller.addAction(.init(title: R.string.localizable.oK(), style: .default))

        presentationViewController.present(controller, animated: true)
    }

    private var presentationViewController: UIViewController {
        if let controller = navigationController.presentedViewController {
            return controller
        } else {
            return navigationController
        }
    }

    func listOfBadTokenScriptFilesChanged(fileNames: [TokenScriptFileIndices.FileName]) {
        tokensCoordinator?.listOfBadTokenScriptFilesChanged(fileNames: fileNames)
    }

    private func createWalletConnectCoordinator() -> WalletConnectCoordinator {
        let coordinator = WalletConnectCoordinator(keystore: keystore, sessions: walletSessions, navigationController: navigationController, analyticsCoordinator: analyticsCoordinator, config: config, nativeCryptoCurrencyPrices: nativeCryptoCurrencyPrices)
        coordinator.delegate = self
        addCoordinator(coordinator)
        return coordinator
    }

    func openWalletConnectSession(url: WalletConnectURL) {
        walletConnectCoordinator.openSession(url: url)
    }

    private func processRestartQueueAndRestartUI() {
        processRestartQueueBeforeRestart(config: config, restartQueue: restartQueue)
        restartUI(withReason: .serverChange, account: wallet)
    }

    private func restartUI(withReason reason: RestartReason, account: Wallet) {
        OpenSea.resetInstances()
        disconnectWalletConnectSessionsSelectively(for: reason)
        delegate?.didRestart(in: self, wallet: account)
    }

    private func processRestartQueueBeforeRestart(config: Config, restartQueue: RestartTaskQueue) {
        for each in restartQueue.queue {
            switch each {
            case .addServer(let server):
                restartQueue.remove(each)
                RPCServer.customRpcs.append(server)
            case .editServer(let original, let edited):
                restartQueue.remove(each)
                replaceServer(original: original, edited: edited)
            case .removeServer(let server):
                restartQueue.remove(each)
                removeServer(server)
            case .enableServer(let server):
                restartQueue.remove(each)
                var c = config
                // NOTE: we need to make sure that we don't enableServer test net server when main net is selected.
                // update enabledServers with added server
                var servers = c.enabledServers.filter({ $0.isTestnet == server.isTestnet })
                servers.append(server)
                c.enabledServers = servers
            case .switchDappServer(server: let server):
                restartQueue.remove(each)
                Config.setChainId(server.chainID)
            case .loadUrlInDappBrowser:
                break
            case .reloadServers(let servers):
                restartQueue.remove(each)
                var c = config
                c.enabledServers = servers
            }
        }
    }

    private func replaceServer(original: CustomRPC, edited: CustomRPC) {
        RPCServer.customRpcs = RPCServer.customRpcs.map { (item: CustomRPC) -> CustomRPC in
            if item.chainID == original.chainID {
                return edited
            }
            return item
        }
    }

    private func removeServer(_ server: CustomRPC) {
        //Must disable server first because we (might) not have done that if the user had disabled and then remove the server in the UI at the same time. And if we fallback to mainnet when an enabled server's chain ID is not found, this can lead to mainnet appearing twice in the Wallet tab
        let servers = config.enabledServers.filter { $0.chainID != server.chainID }
        var config = self.config
        config.enabledServers = servers
        guard let i = RPCServer.customRpcs.firstIndex(of: server) else { return }
        RPCServer.customRpcs.remove(at: i)
        switchBrowserServer(awayFrom: server, config: config)
    }

    private func switchBrowserServer(awayFrom server: CustomRPC, config: Config) {
        if Config.getChainId() == server.chainID {
            //To be safe, we find a network that is either mainnet/testnet depending on the chain that was removed
            let isTestnet = server.isTestnet
            if let targetServer = config.enabledServers.first(where: { $0.isTestnet == isTestnet }) {
                Config.setChainId(targetServer.chainID)
            }
        }
    }

    private func processRestartQueueAfterRestart(config: Config, coordinator: InCoordinator, restartQueue: RestartTaskQueue) {
        for each in restartQueue.queue {
            switch each {
            case .addServer, .reloadServers, .editServer, .removeServer, .enableServer, .switchDappServer:
                break
            case .loadUrlInDappBrowser(let url):
                restartQueue.remove(each)
                coordinator.showTab(.browser)
                coordinator.dappBrowserCoordinator?.open(url: url, animated: false)
            }
        }
    }

    func showWalletQrCode() {
        showTab(.wallet)
        if let nc = tabBarController.viewControllers?.first as? UINavigationController, nc.visibleViewController is RequestViewController {
            //no-op
        } else if navigationController.visibleViewController is RequestViewController {
            //no-op
        } else {
            showPaymentFlow(for: .request, server: config.anyEnabledServer(), navigationController: navigationController)
        }
    }

    private func openFiatOnRamp(wallet: Wallet, server: RPCServer, inViewController viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        let coordinator = FiatOnRampCoordinator(wallet: wallet, server: server, viewController: viewController, source: source, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        coordinator.start()
    }
}

// swiftlint:enable type_body_length
extension InCoordinator: WalletConnectCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func universalScannerSelected(in coordinator: WalletConnectCoordinator) {
        tokensCoordinator?.launchUniversalScanner(fromSource: .walletScreen)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        openFiatOnRamp(wallet: wallet, server: server, inViewController: viewController, source: .transactionActionSheetInsufficientFunds)
    } 
}

extension InCoordinator: CanOpenURL {
    private func open(url: URL, in viewController: UIViewController) {
        //TODO duplication of code to set up a BrowserCoordinator when creating the application's tabbar
        let browserCoordinator = createBrowserCoordinator(sessions: walletSessions, browserOnly: true, analyticsCoordinator: analyticsCoordinator)
        let controller = browserCoordinator.navigationController
        browserCoordinator.open(url: url, animated: false)
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        if contract.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            guard let url = server.etherscanContractDetailsWebPageURL(for: wallet.address) else { return }
            logExplorerUse(type: .wallet)
            open(url: url, in: viewController)
        } else {
            guard let url = server.etherscanTokenDetailsWebPageURL(for: contract) else { return }
            logExplorerUse(type: .token)
            open(url: url, in: viewController)
        }
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        open(url: url, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        open(url: url, in: viewController)
    }
}

extension InCoordinator: TransactionCoordinatorDelegate {
}

extension InCoordinator: ConsoleCoordinatorDelegate {
    func didCancel(in coordinator: ConsoleCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension InCoordinator: SettingsCoordinatorDelegate {

    private func showConsole(navigationController: UINavigationController) {
        let coordinator = ConsoleCoordinator(assetDefinitionStore: assetDefinitionStore, navigationController: navigationController)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showConsole(in coordinator: SettingsCoordinator) {
        showConsole(navigationController: coordinator.navigationController)
    }

    func didCancel(in coordinator: SettingsCoordinator) {
        removeCoordinator(coordinator)

        coordinator.navigationController.dismiss(animated: true)
        delegate?.didCancel(in: self)
    }

    func didRestart(with account: Wallet, in coordinator: SettingsCoordinator, reason: RestartReason) {
        restartUI(withReason: reason, account: account)
    }

    func didUpdateAccounts(in coordinator: SettingsCoordinator) {
        delegate?.didUpdateAccounts(in: self)
    }

    func didPressShowWallet(in coordinator: SettingsCoordinator) {
        //We are only showing the QR code and some text for this address. Maybe have to rework graphic design so that server isn't necessary
        showPaymentFlow(for: .request, server: config.anyEnabledServer(), navigationController: coordinator.navigationController)
        delegate?.didShowWallet(in: self)
    }

    func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController? {
        return delegate?.assetDefinitionsOverrideViewController(for: self)
    }

    func delete(account: Wallet, in coordinator: SettingsCoordinator) {
        Erc1155TokenIdsFetcher.deleteForWallet(account.address)
        TransactionsStorage.deleteAllTransactions(realm: Wallet.functional.realm(forAccount: account))
    }

    func restartToReloadServersQueued(in coordinator: SettingsCoordinator) {
        processRestartQueueAndRestartUI()
    }
}

extension InCoordinator: UrlSchemeResolver {

    func openURLInBrowser(url: URL) {
        openURLInBrowser(url: url, forceReload: false)
    }

    func openURLInBrowser(url: URL, forceReload: Bool) {
        guard let dappBrowserCoordinator = dappBrowserCoordinator else { return }
        showTab(.browser)
        dappBrowserCoordinator.open(url: url, animated: true, forceReload: forceReload)
    }
}

extension InCoordinator: ActivityViewControllerDelegate {
    func reinject(viewController: ActivityViewController) {
        activitiesService.reinject(activity: viewController.viewModel.activity)
    }

    func goToToken(viewController: ActivityViewController) {
        let token = viewController.viewModel.activity.tokenObject
        guard let tokenObject = tokensStorages[token.server].token(forContract: token.contractAddress) else { return }
        guard let tokensCoordinator = tokensCoordinator, let navigationController = viewController.navigationController else { return }

        tokensCoordinator.showSingleChainToken(token: tokenObject, in: navigationController)
    }

    func speedupTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController) {
        guard let transaction = transactionsStorages[server].transaction(withTransactionId: transactionId) else { return }
        let ethPrice = nativeCryptoCurrencyPrices[transaction.server]
        let session = walletSessions[transaction.server]
        guard let coordinator = ReplaceTransactionCoordinator(analyticsCoordinator: analyticsCoordinator, keystore: keystore, ethPrice: ethPrice, presentingViewController: viewController, session: session, transaction: transaction, mode: .speedup) else { return }
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func cancelTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController) {
        guard let transaction = transactionsStorages[server].transaction(withTransactionId: transactionId) else { return }
        let ethPrice = nativeCryptoCurrencyPrices[transaction.server]
        let session = walletSessions[transaction.server]
        guard let coordinator = ReplaceTransactionCoordinator(analyticsCoordinator: analyticsCoordinator, keystore: keystore, ethPrice: ethPrice, presentingViewController: viewController, session: session, transaction: transaction, mode: .cancel) else { return }
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func goToTransaction(viewController: ActivityViewController) {
        transactionCoordinator?.showTransaction(withId: viewController.viewModel.activity.transactionId, server: viewController.viewModel.activity.server, inViewController: viewController)
    }

    func didPressViewContractWebPage(_ contract: AlphaWallet.Address, server: RPCServer, viewController: ActivityViewController) {
        didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }
}

extension InCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if isViewControllerDappBrowserTab(viewController) && viewController == tabBarController.selectedViewController {
            loadHomePageIfNeeded()
            return false
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if isViewControllerDappBrowserTab(viewController) {
            loadHomePageIfEmpty()
        }
    }

    private func loadHomePageIfNeeded() {
        // NOTE: open home web page if tap on browser tab bar icon, should we only when browser opened
        guard let coordinator = dappBrowserCoordinator else { return }

        if let url = config.homePageURL {
            coordinator.open(url: url, animated: false)
        } else {
            coordinator.showDappsHome()
        }
    }

    private func loadHomePageIfEmpty() {
        guard let coordinator = dappBrowserCoordinator, !coordinator.hasWebPageLoaded else { return }

        if let url = config.homePageURL {
            coordinator.open(url: url, animated: false)
        } else {
            coordinator.showDappsHome()
        }
    }
}

extension InCoordinator: WhereAreMyTokensCoordinatorDelegate {

    func switchToMainnetSelected(in coordinator: WhereAreMyTokensCoordinator) {
        restartQueue.add(.reloadServers(Constants.defaultEnabledServers))
        processRestartQueueAndRestartUI()
    }

    func didDismiss(in coordinator: WhereAreMyTokensCoordinator) {
        //no-op
    }
}

extension InCoordinator: TokensCoordinatorDelegate {

    func whereAreMyTokensSelected(in coordinator: TokensCoordinator) {
        let coordinator = WhereAreMyTokensCoordinator(navigationController: navigationController)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    func blockieSelected(in coordinator: TokensCoordinator) {
        delegate?.showWallets(in: self)
    }

    private func showActivity(_ activity: Activity, navigationController: UINavigationController) {
        let controller = ActivityViewController(analyticsCoordinator: analyticsCoordinator, wallet: wallet, assetDefinitionStore: assetDefinitionStore, viewModel: .init(activity: activity), service: activitiesService)
        controller.delegate = self

        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    func didTap(activity: Activity, inViewController viewController: UIViewController, in coordinator: TokensCoordinator) {
        guard let navigationController = viewController.navigationController else { return }

        showActivity(activity, navigationController: navigationController)
    }

    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: TokensCoordinator) {
        logTappedSwap(service: service)
        guard let token = transactionType.swapServiceInputToken, let url = service.url(token: token) else { return }

        if let server = service.rpcServer(forToken: token) {
            open(url: url, onServer: server)
        } else {
            open(for: url)
        }
    }

    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: TokensCoordinator) {
        switch transactionType {
        case .nativeCryptocurrency(let token, _, _), .erc20Token(let token, _, _), .erc875Token(let token, _), .erc721Token(let token, _), .erc1155Token(let token, _, _):
            if shouldSwitchServer {
                open(url: url, onServer: token.server)
            } else {
                open(for: url)
            }
        case .erc875TokenOrder, .erc721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            break
        }
    }

    private func open(for url: URL) {
        guard let dappBrowserCoordinator = dappBrowserCoordinator else { return }
        showTab(.browser)
        dappBrowserCoordinator.open(url: url, animated: true, forceReload: true)
    }

    private func open(url: URL, onServer server: RPCServer) {
        //Server shouldn't be disabled since the action is selected
        guard let dappBrowserCoordinator = dappBrowserCoordinator, config.enabledServers.contains(server) else { return }
        showTab(.browser)
        dappBrowserCoordinator.switch(toServer: server, url: url)
    }

    func didPress(for type: PaymentFlow, server: RPCServer, inViewController viewController: UIViewController?, in coordinator: TokensCoordinator) {
        let navigationController: UINavigationController
        if let nvc = viewController?.navigationController {
            navigationController = nvc
        } else {
            navigationController = coordinator.navigationController
        }

        showPaymentFlow(for: type, server: server, navigationController: navigationController)
    }

    func didTap(transaction: TransactionInstance, inViewController viewController: UIViewController, in coordinator: TokensCoordinator) {
        if transaction.localizedOperations.count > 1 {
            transactionCoordinator?.showTransaction(.group(transaction), inViewController: viewController)
        } else {
            transactionCoordinator?.showTransaction(.standalone(transaction), inViewController: viewController)
        }
    }

    func openConsole(inCoordinator coordinator: TokensCoordinator) {
        showConsole(navigationController: coordinator.navigationController)
    }

    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TokensCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        openFiatOnRamp(wallet: wallet, server: server, inViewController: viewController, source: source)
    }
}

extension InCoordinator: PaymentCoordinatorDelegate {
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: PaymentCoordinator) {
        guard let coordinator = coordinatorOfType(type: TokensCardCollectionCoordinator.self) else { return }

        coordinator.showTokenInstance(tokenHolder: tokenHolder, mode: .preview)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: PaymentCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator) {
        removeCoordinator(coordinator)

        switch result {
        case .sentTransaction(let transaction):
            coordinator.dismiss(animated: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.showTransactionSent(transaction: transaction)
            }
        case .sentRawTransaction, .signedTransaction:
            break
        }
    }

    func didCancel(in coordinator: PaymentCoordinator) {
        coordinator.dismiss(animated: true)

        removeCoordinator(coordinator)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: PaymentCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        openFiatOnRamp(wallet: wallet, server: server, inViewController: viewController, source: source)
    }
}

extension InCoordinator: FiatOnRampCoordinatorDelegate {
}

extension InCoordinator: DappBrowserCoordinatorDelegate {
    func didSentTransaction(transaction: SentTransaction, inCoordinator coordinator: DappBrowserCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func importUniversalLink(url: URL, forCoordinator coordinator: DappBrowserCoordinator) {
        delegate?.importUniversalLink(url: url, forCoordinator: self)
    }

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator) {
        delegate?.handleUniversalLink(url, forCoordinator: self)
    }

    func handleCustomUrlScheme(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator) {
        delegate?.handleCustomUrlScheme(url, forCoordinator: self)
    }

    func restartToAddEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappBrowserCoordinator) {
        processRestartQueueAndRestartUI()
    }

    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappBrowserCoordinator) {
        processRestartQueueAndRestartUI()
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: DappBrowserCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        openFiatOnRamp(wallet: wallet, server: server, inViewController: viewController, source: source)
    }
}

extension InCoordinator: StaticHTMLViewControllerDelegate {
}

extension InCoordinator: TransactionsStorageDelegate {
    func didAddTokensWith(contracts: [AlphaWallet.Address], inTransactionsStorage: TransactionsStorage) {
        for each in contracts {
            assetDefinitionStore.fetchXML(forContract: each)
        }
    }
}

extension InCoordinator: ActivitiesCoordinatorDelegate {

    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController) {
        guard let navigationController = viewController.navigationController else { return }

        showActivity(activity, navigationController: navigationController)
    }

    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController) {
        if transaction.localizedOperations.count > 1 {
            transactionCoordinator?.showTransaction(.group(transaction), inViewController: viewController)
        } else {
            transactionCoordinator?.showTransaction(.standalone(transaction), inViewController: viewController)
        }
    }
}

extension InCoordinator: ClaimOrderCoordinatorDelegate {
    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didFailTransaction error: AnyError) {
        claimOrderCoordinatorCompletionBlock?(false)
    }

    func didClose(in coordinator: ClaimPaidOrderCoordinator) {
        claimOrderCoordinatorCompletionBlock = nil
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didCompleteTransaction result: ConfirmResult) {
        claimOrderCoordinatorCompletionBlock?(true)
        claimOrderCoordinatorCompletionBlock = nil
        removeCoordinator(coordinator)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: ClaimPaidOrderCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        openFiatOnRamp(wallet: wallet, server: server, inViewController: viewController, source: source)
    }
}

// MARK: Analytics
extension InCoordinator {
    private func logEnabledChains() {
        let list = config.enabledServers.map(\.chainID).sorted()
        analyticsCoordinator.setUser(property: Analytics.UserProperties.enabledChains, value: list)
    }

    private func logWallets() {
        let totalCount = keystore.wallets.count
        let hdWalletsCount = keystore.wallets.filter { keystore.isHdWallet(wallet: $0) }.count
        let keystoreWalletsCount = keystore.wallets.filter { keystore.isKeystore(wallet: $0) }.count
        let watchedWalletsCount = keystore.wallets.filter { keystore.isWatched(wallet: $0) }.count
        analyticsCoordinator.setUser(property: Analytics.UserProperties.walletsCount, value: totalCount)
        analyticsCoordinator.setUser(property: Analytics.UserProperties.hdWalletsCount, value: hdWalletsCount)
        analyticsCoordinator.setUser(property: Analytics.UserProperties.keystoreWalletsCount, value: keystoreWalletsCount)
        analyticsCoordinator.setUser(property: Analytics.UserProperties.watchedWalletsCount, value: watchedWalletsCount)
    }

    private func logDynamicTypeSetting() {
        let setting = UIApplication.shared.preferredContentSizeCategory.rawValue
        analyticsCoordinator.setUser(property: Analytics.UserProperties.dynamicTypeSetting, value: setting)
    }

    private func logTappedSwap(service: SwapTokenURLProviderType) {
        analyticsCoordinator.log(navigation: Analytics.Navigation.tokenSwap, properties: [Analytics.Properties.name.rawValue: service.analyticsName])
    }

    private func logExplorerUse(type: Analytics.ExplorerType) {
        analyticsCoordinator.log(navigation: Analytics.Navigation.explorer, properties: [Analytics.Properties.type.rawValue: type.rawValue])
    }
}

extension InCoordinator: ReplaceTransactionCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: ReplaceTransactionCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: ReplaceTransactionCoordinator) {
        removeCoordinator(coordinator)
        switch result {
        case .sentTransaction(let transaction):
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.showTransactionSent(transaction: transaction)
            }
        case .sentRawTransaction, .signedTransaction:
            break
        }
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: ReplaceTransactionCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        openFiatOnRamp(wallet: wallet, server: server, inViewController: viewController, source: source)
    }
}

extension InCoordinator: WhatsNewExperimentCoordinatorDelegate {
    func didEnd(in coordinator: WhatsNewExperimentCoordinator) {
        removeCoordinator(coordinator)
    }
}
// swiftlint:enable file_length
