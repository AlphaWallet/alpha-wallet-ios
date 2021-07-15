// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt
import PromiseKit
import RealmSwift
import Result

// swiftlint:disable file_length
protocol InCoordinatorDelegate: class {
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
    //TODO rename this generic name to reflect that it's for event instances, not for event activity
    lazy private var eventsDataStore: EventsDataStore = EventsDataStore(realm: realm)
    lazy private var eventsActivityDataStore: EventsActivityDataStore = EventsActivityDataStore(realm: realm)
    private var eventSourceCoordinator: EventSourceCoordinator?
    private var eventSourceCoordinatorForActivities: EventSourceCoordinatorForActivities?
    private let coinTickersFetcher: CoinTickersFetcherType 
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
        return HelpUsCoordinator(
                navigationController: navigationController,
                appTracker: appTracker
        )
    }()

    lazy var filterTokensCoordinator: FilterTokensCoordinator = {
        return .init(assetDefinitionStore: assetDefinitionStore, tokenActionsService: tokenActionsService)
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var keystore: Keystore
    var urlSchemeCoordinator: UrlSchemeCoordinatorType
    weak var delegate: InCoordinatorDelegate?

    private let walletBalanceCoordinator: WalletBalanceCoordinatorType

    private lazy var realm = Self.realm(forAccount: wallet)
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

        return service
    }()

    private lazy var walletConnectCoordinator: WalletConnectCoordinator = createWalletConnectCoordinator()

    private let promptBackupCoordinator: PromptBackupCoordinator

    lazy var tabBarController: UITabBarController = {
        let tabBarController = TabBarController()
        tabBarController.tabBar.isTranslucent = false
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
    }

    func launchUniversalScanner() {
        tokensCoordinator?.launchUniversalScanner(fromSource: .quickAction)
    }

    private func setupWatchingTokenScriptFileChangesToFetchEvents() {
        //TODO this is firing twice for each contract. We can be more efficient
        assetDefinitionStore.subscribeToBodyChanges { [weak self] contract in
            guard let strongSelf = self else { return }
            let tokens = strongSelf.tokensStorages.values.flatMap { $0.enabledObject }
            //Assume same contract don't exist in multiple chains
            guard let token = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) else { return }
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
        }
    }

    private func fetchEvents(forTokenContract contract: AlphaWallet.Address, server: RPCServer) {
        let tokensDataStore = tokensStorages[server]
        guard let token = tokensDataStore.token(forContract: contract) else { return }
        eventsDataStore.deleteEvents(forTokenContract: contract)
        let _ = eventSourceCoordinator?.fetchEventsByTokenId(forToken: token)
        if Features.isActivityEnabled {
            let _ = eventSourceCoordinatorForActivities?.fetchEvents(forToken: token)
        }
    }

    private func createTokensDatastore(forConfig config: Config, server: RPCServer) -> TokensDataStore {
        let storage = TokensDataStore(realm: realm, account: wallet, server: server, config: config, assetDefinitionStore: assetDefinitionStore, filterTokensCoordinator: filterTokensCoordinator)
        storage.priceDelegate = self
        return storage
    }

    private func createTransactionsStorage(server: RPCServer) -> TransactionsStorage {
        return TransactionsStorage(realm: realm, server: server, delegate: self)
    }

    private func fetchCryptoPrice(forServer server: RPCServer) {
        assert(!tokensStorages.isEmpty)

        let tokensStorage = tokensStorages[server]

        tokensStorage.tokensModel.subscribe { [weak self, weak tokensStorage] tokensModel in
            guard let strongSelf = self, let tokensStorage = tokensStorage else { return }
            let etherToken = TokensDataStore.etherToken(forServer: server)
            guard let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else { return }
            //Defensive. Sometimes crash right after switch networks if price is refreshed just before the TokensStorage is destroyed
            guard strongSelf.nativeCryptoCurrencyPrices.hasKey(server) else { return }
            if let ticker = tokensStorage.coinTicker(for: eth) {
                strongSelf.nativeCryptoCurrencyPrices[server].value = Double(ticker.price_usd)
            } else {
                tokensStorage.updatePricesAfterComingOnline()
            }
        }
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

    private func setUpEventSourceCoordinator() {
        eventSourceCoordinator = EventSourceCoordinator(wallet: wallet, config: config, tokensStorages: tokensStorages, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
    }

    private func setUpEventSourceCoordinatorForActivities() {
        guard Features.isActivityEnabled else { return }
        eventSourceCoordinatorForActivities = EventSourceCoordinatorForActivities(wallet: wallet, config: config, tokensStorages: tokensStorages, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsActivityDataStore)
        eventSourceCoordinatorForActivities?.delegate = self
    }

    private func setupTokenDataStores() {
        tokensStorages = .init()
        for each in config.enabledServers {
            let tokensStorage = createTokensDatastore(forConfig: config, server: each)
            tokensStorages[each] = tokensStorage
        }
    }

    private func setupFetchTokenPrices() {
        fetchTokenPrices()
    }

    private func fetchTokenPrices() {
        let tokens: ServerDictionary<[TokenMappedToTicker]> = tokensStorages.mapValues { storage in
            storage.enabledObject.map { TokenMappedToTicker(tokenObject: $0) }
        }

        firstly {
            coinTickersFetcher.fetchPrices(forTokens: tokens)
        }.done { [weak self] tickers in
            guard let strongSelf = self else { return }
            for (_, storage) in strongSelf.tokensStorages {
                storage.tickers = tickers
            }
        }.catch {
            if $0 == CoinTickersFetcher.Error.alreadyFetchingPrices {
                //no-op
            } else {
                //We should already have retried upstream
                //TODO good to log to remote, but might be connectivity problem etc
            }
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

    private func setupEtherBalances() {
        nativeCryptoCurrencyBalances = .init()
        for each in config.enabledServers {
            nativeCryptoCurrencyBalances[each] = createCryptoCurrencyBalanceSubscribable(forServer: each)
            let tokensStorage = tokensStorages[each]

            tokensStorage.tokensModel.subscribe { [weak self] tokensModel in
                let etherToken = TokensDataStore.etherToken(forServer: each)
                guard let strongSelf = self, let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else {
                    return
                }

                if let balance = BigInt(eth.value) {
                    //Defensive. Sometimes crash right after switch networks if price is refreshed just before the TokensStorage is destroyed
                    guard strongSelf.nativeCryptoCurrencyBalances.hasKey(each) else { return }
                    strongSelf.nativeCryptoCurrencyBalances[each].value = BigInt(eth.value)
                    guard !(balance.isZero) else { return }
                    //TODO don't backup wallets if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
                    guard !isRunningTests() else { return }
                }
            }
        }
    }

    private func setupWalletSessions() {
        walletSessions = .init()
        for each in config.enabledServers {
            let tokensStorage = tokensStorages[each]
            let balanceCoordinator = BalanceCoordinator(wallet: wallet, server: each, storage: tokensStorage)
            let session = WalletSession(
                    account: wallet,
                    server: each,
                    config: config,
                    balanceCoordinator: balanceCoordinator
            )
            walletSessions[each] = session
        }
    }

    //Setup functions has to be called in the right order as they may rely on eg. wallet sessions being available. Wrong order should be immediately apparent with crash on startup. So don't worry
    private func setupResourcesOnMultiChain() {
        oneTimeCreationOfOneDatabaseToHoldAllChains()
        setupTokenDataStores()
        setupFetchTokenPrices()
        setupWalletSessions()
        setupNativeCryptoCurrencyPrices()
        setupNativeCryptoCurrencyBalances()
        setupEventsStorages()
        setupTransactionsStorages()
        setupEtherBalances()
        setupCallForAssetAttributeCoordinators()
        //TODO rename this generic name to reflect that it's for event instances, not for event activity. A few other related ones too
        setUpEventSourceCoordinator()
        setUpEventSourceCoordinatorForActivities()
        setUpErc721TokenIdsFetcher()
    }

    private func setUpErc721TokenIdsFetcher() {
        for each in config.enabledServers {
            let tokenStorage = tokensStorages[each]
            let transactionStorage = transactionsStorages[each]
            tokenStorage.erc721TokenIdsFetcher = transactionStorage
        }
    }

    private func setupEventsStorages() {
        eventsDataStore = EventsDataStore(realm: realm)
        eventsActivityDataStore = EventsActivityDataStore(realm: realm)
    }
    private func setupNativeCryptoCurrencyPrices() {
        nativeCryptoCurrencyPrices = createEtherPricesSubscribablesForAllChains()
    }

    private func setupNativeCryptoCurrencyBalances() {
        nativeCryptoCurrencyBalances = createEtherBalancesSubscribablesForAllChains()
    }

    private func fetchEthereumEvents() {
        eventSourceCoordinator?.fetchEthereumEvents()
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

    private func createTokensCoordinator(promptBackupCoordinator: PromptBackupCoordinator) -> TokensCoordinator {
        let tokensStoragesForEnabledServers = config.enabledServers.map { tokensStorages[$0] }
        let tokenCollection = TokenCollection(filterTokensCoordinator: filterTokensCoordinator, tokenDataStores: tokensStoragesForEnabledServers)
        promptBackupCoordinator.listenToNativeCryptoCurrencyBalance(withTokenCollection: tokenCollection)
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
                coinTickersFetcher: coinTickersFetcher
        )

        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet(), selectedImage: nil)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createTransactionCoordinator(promptBackupCoordinator: PromptBackupCoordinator) -> TransactionCoordinator {
        let transactionsStoragesForEnabledServers = config.enabledServers.map { transactionsStorages[$0] }
        let transactionsCollection = TransactionCollection(transactionsStorages: transactionsStoragesForEnabledServers)
        let coordinator = TransactionCoordinator(
                analyticsCoordinator: analyticsCoordinator,
                sessions: walletSessions,
                transactionsCollection: transactionsCollection,
                keystore: keystore,
                tokensStorages: tokensStorages,
                promptBackupCoordinator: promptBackupCoordinator
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.transactionsTabbarItemTitle(), image: R.image.tab_transactions(), selectedImage: nil)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createActivityCoordinator() -> ActivitiesCoordinator {
        let coordinator = ActivitiesCoordinator(
                analyticsCoordinator: analyticsCoordinator,
                config: config,
                sessions: walletSessions,
                keystore: keystore,
                tokensStorages: tokensStorages,
                assetDefinitionStore: assetDefinitionStore,
                eventsActivityDataStore: eventsActivityDataStore,
                eventsDataStore: eventsDataStore,
                transactionCoordinator: transactionCoordinator
        )
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

        let tokensCoordinator = createTokensCoordinator(promptBackupCoordinator: promptBackupCoordinator)
        configureNavigationControllerForLargeTitles(tokensCoordinator.navigationController)
        viewControllers.append(tokensCoordinator.navigationController)

        let transactionCoordinator = createTransactionCoordinator(promptBackupCoordinator: promptBackupCoordinator)
        configureNavigationControllerForLargeTitles(transactionCoordinator.navigationController)
        if Features.isActivityEnabled {
            let activityCoordinator = createActivityCoordinator()
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
        let session = walletSessions[server]
        let tokenStorage = tokensStorages[server]

        switch (type, session.account.type) {
        case (.send, .real), (.request, _):
            let coordinator = PaymentCoordinator(
                    navigationController: navigationController,
                    flow: type,
                    session: session,
                    keystore: keystore,
                    storage: tokenStorage,
                    ethPrice: nativeCryptoCurrencyPrices[server],
                    assetDefinitionStore: assetDefinitionStore,
                    analyticsCoordinator: analyticsCoordinator
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
        transactionCoordinator?.dataCoordinator.addSentTransaction(transaction)
    }

    private static func realm(forAccount account: Wallet) -> Realm {
        let migration = MigrationInitializer(account: account)
        migration.perform()
        return try! Realm(configuration: migration.config)
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
        let value = Subscribable<Double>(nil)
        fetchCryptoPrice(forServer: server)
        return value
    }

    private func createEtherBalancesSubscribablesForAllChains() -> ServerDictionary<Subscribable<BigInt>> {
        var result = ServerDictionary<Subscribable<BigInt>>()
        for each in config.enabledServers {
            result[each] = createCryptoCurrencyBalanceSubscribable(forServer: each)
        }
        return result
    }

    private func createCryptoCurrencyBalanceSubscribable(forServer server: RPCServer) -> Subscribable<BigInt> {
        return Subscribable<BigInt>(nil)
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
            case .removeServer(let server):
                restartQueue.remove(each)
                removeServer(server)
            case .enableServer(let server):
                restartQueue.remove(each)
                var c = config
                c.enabledServers.append(server)
            case .switchDappServer(server: let server):
                restartQueue.remove(each)
                Config.setChainId(server.chainID)
            case .loadUrlInDappBrowser:
                break
            }
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
            case .addServer, .removeServer, .enableServer, .switchDappServer:
                break
            case .loadUrlInDappBrowser(let url):
                restartQueue.remove(each)
                coordinator.showTab(.browser)
                coordinator.dappBrowserCoordinator?.open(url: url, animated: false)
            }
        }
    }
}

// swiftlint:enable type_body_length
extension InCoordinator: WalletConnectCoordinatorDelegate {
    func universalScannerSelected(in coordinator: WalletConnectCoordinator) {
        tokensCoordinator?.launchUniversalScanner(fromSource: .walletScreen)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: WalletConnectCoordinator) {
        handlePendingTransaction(transaction: transaction)
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
        let realm = Self.realm(forAccount: account)
        for each in RPCServer.allCases {
            let transactionsStorage = TransactionsStorage(realm: realm, server: each, delegate: nil)
            transactionsStorage.deleteAll()
        }
    }

    func restartToAddEnableAndSwitchBrowserToServer(in coordinator: SettingsCoordinator) {
        processRestartQueueAndRestartUI()
    }

    func restartToRemoveServer(in coordinator: SettingsCoordinator) {
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

extension InCoordinator: TokensCoordinatorDelegate {

    func blockieSelected(in coordinator: TokensCoordinator) {
        delegate?.showWallets(in: self)
    }

    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: TokensCoordinator) {
        logTappedSwap(service: service)
        guard let token = transactionType.swapServiceInputToken, let url = service.url(token: token) else { return }

        if let server = service.rpcServer {
            open(url: url, onServer: server)
        } else {
            open(for: url)
        }
    }

    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: TokensCoordinator) {
        switch transactionType {
        case .nativeCryptocurrency(let token, _, _), .ERC20Token(let token, _, _), .ERC875Token(let token), .ERC721Token(let token):
            if shouldSwitchServer {
                open(url: url, onServer: token.server)
            } else {
                open(for: url)
            }
        case .ERC875TokenOrder, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
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

    func didPress(for type: PaymentFlow, server: RPCServer, in coordinator: TokensCoordinator) {
        showPaymentFlow(for: type, server: server, navigationController: coordinator.navigationController)
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
}

extension InCoordinator: PaymentCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator) {
        removeCoordinator(coordinator)

        switch result {
        case .sentTransaction(let transaction):
            handlePendingTransaction(transaction: transaction)

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

extension InCoordinator: EventSourceCoordinatorForActivitiesDelegate {
    func didUpdate(inCoordinator coordinator: EventSourceCoordinatorForActivities) {
        activityCoordinator?.reload()
    }
}

extension InCoordinator: ActivitiesCoordinatorDelegate {

    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController) {
        if transaction.localizedOperations.count > 1 {
            transactionCoordinator?.showTransaction(.group(transaction), inViewController: viewController)
        } else {
            transactionCoordinator?.showTransaction(.standalone(transaction), inViewController: viewController)
        }
    }

    func show(tokenObject: TokenObject, fromCoordinator coordinator: ActivitiesCoordinator) {
        guard let tokensCoordinator = tokensCoordinator else { return }

        tokensCoordinator.showSingleChainToken(token: tokenObject, in: coordinator.navigationController)
    }

    func speedup(transactionWithId transactionId: String, forServer server: RPCServer, viewController: ActivityViewController, fromCoordinator coordinator: ActivitiesCoordinator) {
        guard let transaction = transactionsStorages[server].transactions.first(where: { $0.id == transactionId }) else { return }
        let ethPrice = nativeCryptoCurrencyPrices[transaction.server]
        let session = walletSessions[transaction.server]
        guard let coordinator = ReplaceTransactionCoordinator(analyticsCoordinator: analyticsCoordinator, keystore: keystore, ethPrice: ethPrice, presentingViewController: viewController, session: session, transaction: transaction, mode: .speedup) else { return }
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func cancel(transactionWithId transactionId: String, forServer server: RPCServer, viewController: ActivityViewController, fromCoordinator coordinator: ActivitiesCoordinator) {
        guard let transaction = transactionsStorages[server].transactions.first(where: { $0.id == transactionId }) else { return }
        let ethPrice = nativeCryptoCurrencyPrices[transaction.server]
        let session = walletSessions[transaction.server]
        guard let coordinator = ReplaceTransactionCoordinator(analyticsCoordinator: analyticsCoordinator, keystore: keystore, ethPrice: ethPrice, presentingViewController: viewController, session: session, transaction: transaction, mode: .cancel) else { return }
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func show(transactionWithId transactionId: String, server: RPCServer, inViewController viewController: UIViewController, fromCoordinator coordinator: ActivitiesCoordinator) {
        transactionCoordinator?.showTransaction(withId: transactionId, server: server, inViewController: viewController)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, fromCoordinator coordinator: ActivitiesCoordinator, inViewController viewController: UIViewController) {
        didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
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

    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didCompleteTransaction result: TransactionConfirmationResult) {
        claimOrderCoordinatorCompletionBlock?(true)
        claimOrderCoordinatorCompletionBlock = nil
        removeCoordinator(coordinator)
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
}

extension InCoordinator: TokensDataStorePriceDelegate {
    func updatePrice(forTokenDataStore tokensDataStore: TokensDataStore) {
        fetchTokenPrices()
    }
}
// swiftlint:enable file_length
