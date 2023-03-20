import UIKit
import PromiseKit
import Combine
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletCore

// swiftlint:disable file_length
protocol ActiveWalletCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: ActiveWalletCoordinator)
    func didShowWallet(in coordinator: ActiveWalletCoordinator)
    func handleUniversalLink(_ url: URL, forCoordinator coordinator: ActiveWalletCoordinator, source: UrlSource)
    func showWallets(in coordinator: ActiveWalletCoordinator)
    func didRestart(in coordinator: ActiveWalletCoordinator, reason: RestartReason, wallet: Wallet)
}

// swiftlint:disable type_body_length
class ActiveWalletCoordinator: NSObject, Coordinator {
    private let wallet: Wallet
    private let config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    private let appTracker: AppTracker
    private let analytics: AnalyticsLogger
    private let restartHandler: RestartQueueHandler
    private let coinTickersFetcher: CoinTickersFetcher
    private let transactionsDataStore: TransactionDataStore
    private let blockscanChatService: BlockscanChatService
    private let activitiesPipeLine: ActivitiesPipeLine
    private let sessionsProvider: SessionsProvider
    private let currencyService: CurrencyService
    private lazy var tokensFilter: TokensFilter = {
        return TokensFilter(
            tokenActionsService: tokenActionsService,
            tokenGroupIdentifier: TokenGroupIdentifier.identifier(fromFileName: "tokens")!)
    }()

    internal let tokenCollection: TokenCollection

    var transactionCoordinator: TransactionsCoordinator? {
        return coordinators.compactMap { $0 as? TransactionsCoordinator }.first
    }
    var tokensCoordinator: TokensCoordinator? {
        return coordinators.compactMap { $0 as? TokensCoordinator }.first
    }
    var dappBrowserCoordinator: DappBrowserCoordinator? {
        coordinators.compactMap { $0 as? DappBrowserCoordinator }.first
    }
    var activityCoordinator: ActivitiesCoordinator? {
        return coordinators.compactMap { $0 as? ActivitiesCoordinator }.first
    }
    var settingsCoordinator: SettingsCoordinator? {
        return coordinators.compactMap { $0 as? SettingsCoordinator }.first
    }
    private lazy var helpUsCoordinator: HelpUsCoordinator = {
        HelpUsCoordinator(hostViewController: navigationController, appTracker: appTracker, analytics: analytics)
    }()

    private lazy var whatsNewExperimentCoordinator: WhatsNewExperimentCoordinator = {
        let coordinator = WhatsNewExperimentCoordinator(
            navigationController: navigationController,
            userDefaults: UserDefaults.standardOrForTests,
            analytics: analytics)

        coordinator.delegate = self
        return coordinator
    }()
    private var pendingOperation: PendingOperation?

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var keystore: Keystore
    var universalLinkService: UniversalLinkService

    weak var delegate: ActiveWalletCoordinatorDelegate?

    private let walletBalanceService: WalletBalanceService
    private var tokenActionsService: TokenActionsService
    private let walletConnectCoordinator: WalletConnectCoordinator
    private let promptBackup: PromptBackup
    private let tokenImageFetcher: TokenImageFetcher
    private lazy var promptBackupCoordinator: PromptBackupCoordinator = {
        return PromptBackupCoordinator(
            wallet: wallet,
            promptBackup: promptBackup,
            keystore: keystore,
            analytics: analytics)
    }()

    private (set) var swapButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(R.image.swap(), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()

    lazy var tabBarController: UITabBarController = {
        let tabBarController: UITabBarController = .withOverridenBarAppearence()
        tabBarController.delegate = self

        if Environment.isDebug && Features.default.isAvailable(.isSwapEnabled) {
            tabBarController.tabBar.addSubview(swapButton)
            swapButton.topAnchor.constraint(equalTo: tabBarController.tabBar.topAnchor, constant: 2).isActive = true
            swapButton.centerXAnchor.constraint(equalTo: tabBarController.tabBar.centerXAnchor).isActive = true
        } else {
            //no-op
        }

        return tabBarController
    }()

    private let accountsCoordinator: AccountsCoordinator

    var presentationNavigationController: UINavigationController {
        if let nc = UIApplication.shared.presentedViewController(or: navigationController) as? UINavigationController {
            if let nc = nc.presentedViewController as? UINavigationController {
                return nc
            } else {
                return nc
            }
        } else {
            return navigationController
        }
    }

    private lazy var transactionNotificationService: NotificationSourceService = {
        let service = TransactionNotificationSourceService(
            transactionDataStore: transactionsDataStore,
            config: config,
            serversProvider: serversProvider)
        
        service.delegate = promptBackup
        return service
    }()
    private let notificationService: NotificationService
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainResolutionServiceType
    private let tokenSwapper: TokenSwapper
    private let tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable
    private let lock: Lock
    private let tokenScriptOverridesFileManager: TokenScriptOverridesFileManager
    private var cancelable = Set<AnyCancellable>()
    private let networkService: NetworkService
    private let serversProvider: ServersProvidable

    init(navigationController: UINavigationController = NavigationController(),
         activitiesPipeLine: ActivitiesPipeLine,
         wallet: Wallet,
         keystore: Keystore,
         assetDefinitionStore: AssetDefinitionStore,
         config: Config,
         appTracker: AppTracker = AppTracker(),
         analytics: AnalyticsLogger,
         restartHandler: RestartQueueHandler,
         universalLinkCoordinator: UniversalLinkService,
         accountsCoordinator: AccountsCoordinator,
         walletBalanceService: WalletBalanceService,
         coinTickersFetcher: CoinTickersFetcher,
         tokenActionsService: TokenActionsService,
         walletConnectCoordinator: WalletConnectCoordinator,
         notificationService: NotificationService,
         blockiesGenerator: BlockiesGenerator,
         domainResolutionService: DomainResolutionServiceType,
         tokenSwapper: TokenSwapper,
         sessionsProvider: SessionsProvider,
         tokenCollection: TokenCollection,
         transactionsDataStore: TransactionDataStore,
         tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable,
         lock: Lock,
         currencyService: CurrencyService,
         tokenScriptOverridesFileManager: TokenScriptOverridesFileManager,
         networkService: NetworkService,
         promptBackup: PromptBackup,
         caip10AccountProvidable: CAIP10AccountProvidable,
         tokenImageFetcher: TokenImageFetcher,
         serversProvider: ServersProvidable) {

        self.serversProvider = serversProvider
        self.tokenImageFetcher = tokenImageFetcher
        self.promptBackup = promptBackup
        self.networkService = networkService
        self.currencyService = currencyService
        self.tokenScriptOverridesFileManager = tokenScriptOverridesFileManager
        self.lock = lock
        self.tokensService = tokensService
        self.transactionsDataStore = transactionsDataStore
        self.tokenCollection = tokenCollection
        self.activitiesPipeLine = activitiesPipeLine
        self.tokenSwapper = tokenSwapper
        self.sessionsProvider = sessionsProvider
        self.walletConnectCoordinator = walletConnectCoordinator
        self.navigationController = navigationController
        self.wallet = wallet
        self.keystore = keystore
        self.config = config
        self.appTracker = appTracker
        self.analytics = analytics
        self.restartHandler = restartHandler
        self.assetDefinitionStore = assetDefinitionStore
        self.universalLinkService = universalLinkCoordinator
        self.accountsCoordinator = accountsCoordinator
        self.walletBalanceService = walletBalanceService
        self.coinTickersFetcher = coinTickersFetcher
        self.tokenActionsService = tokenActionsService
        self.blockscanChatService = BlockscanChatService(
            keystore: keystore,
            account: wallet,
            analytics: analytics,
            networkService: networkService)
        self.notificationService = notificationService
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService
        //Disabled for now. Refer to function's comment
        //self.assetDefinitionStore.enableFetchXMLForContractInPasteboard()
        super.init()
        blockscanChatService.delegate = self

        self.keystore.recentlyUsedWallet = wallet
        crashlytics.trackActiveWallet(wallet: wallet)
        caip10AccountProvidable.set(activeWallet: wallet)
        notificationService.register(source: transactionNotificationService)
        swapButton.addTarget(self, action: #selector(swapButtonSelected), for: .touchUpInside)

        addCoordinator(promptBackupCoordinator)
    }

    deinit {
        notificationService.unregister(source: transactionNotificationService)
    }

    func start(animated: Bool) {
        donateWalletShortcut()

        setupResourcesOnMultiChain()
        walletConnectCoordinator.delegate = self
        setupTabBarController()

        showTabBar(animated: animated)

        checkDevice()
        showHelpUs()

        fetchXMLAssetDefinitions()

        restartHandler.processRestartQueueAfterRestart(provider: self)

        showWhatsNew()
        notificationService.start(wallet: wallet)
        handleTokenScriptOverrideImport()
    }

    private func handleTokenScriptOverrideImport() {
        tokenScriptOverridesFileManager
            .importTokenScriptOverridesFileEvent
            .sink { [weak self, sessionsProvider, wallet] event in
                switch event {
                case .failure(let error):
                    self?.show(error: error)
                case .success(let override):
                    guard let session = sessionsProvider.session(for: override.server) else { return }
                    session.importToken.importToken(for: override.contract, onlyIfThereIsABalance: false)
                        .sinkAsync(receiveCompletion: { result in
                            guard case .failure(let error) = result else { return }
                            debugLog("Error while adding imported token contract: \(override.contract.eip55String) server: \(override.server) wallet: \(wallet.address.eip55String) error: \(error)")
                        })
                    if !override.destinationFileInUse {
                        self?.show(openedURL: override.filename)
                    }
                }
            }.store(in: &cancelable)
    }

    private func showHelpUs() {
        helpUsCoordinator.start()
        addCoordinator(helpUsCoordinator)
    }

    @objc private func swapButtonSelected(_ sender: UIButton) {
        let coordinator = WalletPupupCoordinator(navigationController: navigationController)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    private func showWhatsNew() {
        whatsNewExperimentCoordinator.start()
        addCoordinator(whatsNewExperimentCoordinator)
    }

    private func donateWalletShortcut() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            WalletQrCodeDonation(address: self.wallet.address).donate()
        }
    }

    func launchUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        tokensCoordinator?.launchUniversalScanner(fromSource: source)
    }

    private func oneTimeCreationOfOneDatabaseToHoldAllChains() {
        let migration = DatabaseMigration(account: wallet)
        migration.oneTimeCreationOfOneDatabaseToHoldAllChains(assetDefinitionStore: assetDefinitionStore)
    }

    //Setup functions has to be called in the right order as they may rely on eg. wallet sessions being available. Wrong order should be immediately apparent with crash on startup. So don't worry
    private func setupResourcesOnMultiChain() {
        oneTimeCreationOfOneDatabaseToHoldAllChains()
    }

    func showTabBar(animated: Bool) {
        navigationController.setViewControllers([accountsCoordinator.accountsViewController], animated: false)
        navigationController.pushViewController(tabBarController, animated: animated)

        navigationController.setNavigationBarHidden(true, animated: false)

        let viewModel = ActiveWalletViewModel()
        showTab(viewModel.initialTab)

        logEnabledChains()
        logWallets()
        logDynamicTypeSetting()
        logIsAppPasscodeOrBiometricProtectionEnabled()
        promptBackupCoordinator.start()

        universalLinkService.handlePendingUniversalLink(in: self)
    }

    private func createTokensCoordinator() -> TokensCoordinator {
        let coordinator = TokensCoordinator(
            sessionsProvider: sessionsProvider,
            keystore: keystore,
            config: config,
            assetDefinitionStore: assetDefinitionStore,
            promptBackupCoordinator: promptBackupCoordinator,
            analytics: analytics,
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: walletConnectCoordinator,
            coinTickersFetcher: coinTickersFetcher,
            activitiesService: activitiesPipeLine,
            walletBalanceService: walletBalanceService,
            tokenCollection: tokenCollection,
            blockiesGenerator: blockiesGenerator,
            domainResolutionService: domainResolutionService,
            tokensFilter: tokensFilter,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher)

        coordinator.rootViewController.tabBarItem = ActiveWalletViewModel.Tabs.tokens.tabBarItem
        coordinator.delegate = self
        coordinator.start()

        addCoordinator(coordinator)
        return coordinator
    }

    private func createTransactionCoordinator() -> TransactionsCoordinator {
        let transactionsService = TransactionsService(
            sessionsProvider: sessionsProvider,
            transactionDataStore: transactionsDataStore,
            analytics: analytics,
            tokensService: tokensService,
            networkService: networkService,
            assetDefinitionStore: assetDefinitionStore)

        let coordinator = TransactionsCoordinator(
            analytics: analytics,
            sessionsProvider: sessionsProvider,
            transactionsService: transactionsService,
            tokensService: tokenCollection,
            tokenImageFetcher: tokenImageFetcher)

        coordinator.rootViewController.tabBarItem = ActiveWalletViewModel.Tabs.transactions.tabBarItem
        coordinator.navigationController.configureForLargeTitles()
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)

        return coordinator
    }

    private func createActivityCoordinator() -> ActivitiesCoordinator {
        let coordinator = ActivitiesCoordinator(
            analytics: analytics,
            sessionsProvider: sessionsProvider,
            activitiesService: activitiesPipeLine,
            keystore: keystore,
            wallet: wallet,
            assetDefinitionStore: assetDefinitionStore,
            tokenImageFetcher: tokenImageFetcher)

        coordinator.delegate = self
        coordinator.start()
        coordinator.rootViewController.tabBarItem = ActiveWalletViewModel.Tabs.activities.tabBarItem
        coordinator.navigationController.configureForLargeTitles()
        addCoordinator(coordinator)

        return coordinator
    }

    private func createBrowserCoordinator(browserOnly: Bool) -> DappBrowserCoordinator {
        let coordinator = DappBrowserCoordinator(
            sessionsProvider: sessionsProvider,
            config: config,
            browserOnly: browserOnly,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            bookmarksStore: BookmarksStore(),
            browserHistoryStorage: BrowserHistoryStorage(ignoreUrls: [Constants.dappsBrowserURL]),
            wallet: wallet,
            networkService: networkService)

        coordinator.delegate = self
        coordinator.start()
        coordinator.rootViewController.tabBarItem = ActiveWalletViewModel.Tabs.browser.tabBarItem
        addCoordinator(coordinator)

        return coordinator
    }

    private func createSettingsCoordinator() -> SettingsCoordinator {
        let coordinator = SettingsCoordinator(
            keystore: keystore,
            config: config,
            sessionsProvider: sessionsProvider,
            restartHandler: restartHandler,
            promptBackupCoordinator: promptBackupCoordinator,
            analytics: analytics,
            walletConnectCoordinator: walletConnectCoordinator,
            walletBalanceService: walletBalanceService,
            blockscanChatService: blockscanChatService,
            blockiesGenerator: blockiesGenerator,
            domainResolutionService: domainResolutionService,
            lock: lock,
            currencyService: currencyService,
            tokenScriptOverridesFileManager: tokenScriptOverridesFileManager,
            networkService: networkService,
            promptBackup: promptBackup,
            serversProvider: serversProvider)

        coordinator.rootViewController.tabBarItem = ActiveWalletViewModel.Tabs.settings.tabBarItem
        coordinator.navigationController.configureForLargeTitles()
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)

        return coordinator
    }

    private func setupTabBarController() {
        var viewControllers = [UIViewController]()

        let tokensCoordinator = createTokensCoordinator()
        viewControllers.append(tokensCoordinator.navigationController)

        let transactionCoordinator = createTransactionCoordinator()

        if Features.default.isAvailable(.isActivityEnabled) {
            let activityCoordinator = createActivityCoordinator()
            viewControllers.append(activityCoordinator.navigationController)
        } else {
            viewControllers.append(transactionCoordinator.navigationController)
        }
        if Environment.isDebug && Features.default.isAvailable(.isSwapEnabled) {
            let swapDummyViewController = UIViewController()
            swapDummyViewController.tabBarItem = ActiveWalletViewModel.Tabs.swap.tabBarItem
            viewControllers.append(swapDummyViewController)
        }

        let browserCoordinator = createBrowserCoordinator(browserOnly: false)
        viewControllers.append(browserCoordinator.navigationController)

        let settingsCoordinator = createSettingsCoordinator()
        viewControllers.append(settingsCoordinator.navigationController)

        tabBarController.viewControllers = viewControllers
    }

    func showTab(_ selectTab: ActiveWalletViewModel.Tabs) {
        guard let viewControllers = tabBarController.viewControllers else {
            return
        }

        for controller in viewControllers {
            if let nav = controller as? UINavigationController, nav.viewControllers[0].className == selectTab.className {
                tabBarController.selectedViewController = nav
                loadHomePageIfEmpty()
            }
        }
    }

    private func checkDevice() {
        let deviceChecker = CheckDeviceCoordinator(navigationController: navigationController, jailbreakChecker: DeviceChecker())
        deviceChecker.start()
        addCoordinator(deviceChecker)
    }

    func showPaymentFlow(for type: PaymentFlow, server: RPCServer, navigationController: UINavigationController) {
        switch (type, wallet.type) {
        case (.send, .real), (.swap, .real), (.request, _),
            (_, _) where Config().development.shouldPretendIsRealWallet:
            let coordinator = PaymentCoordinator(
                navigationController: navigationController,
                flow: type,
                server: server,
                sessionsProvider: sessionsProvider,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
                analytics: analytics,
                tokenCollection: tokenCollection,
                domainResolutionService: domainResolutionService,
                tokenSwapper: tokenSwapper,
                tokensFilter: tokensFilter,
                networkService: networkService,
                transactionDataStore: transactionsDataStore,
                tokenImageFetcher: tokenImageFetcher)

            coordinator.delegate = self
            coordinator.start()

            addCoordinator(coordinator)
        case (_, _):
            if let topVC = navigationController.presentedViewController {
                topVC.displayError(error: ActiveWalletViewModel.Error.onlyWatchAccount)
            } else {
                navigationController.displayError(error: ActiveWalletViewModel.Error.onlyWatchAccount)
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
        let fetch = FetchTokenScriptFiles(
            assetDefinitionStore: assetDefinitionStore,
            tokensService: tokensService,
            serversProvider: serversProvider)

        fetch.start()
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
        let controller = UIAlertController(title: nil, message: R.string.localizable.tokenscriptImportOk(filename), preferredStyle: .alert)
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

    func openWalletConnectSession(url: AlphaWallet.WalletConnect.ConnectionUrl) {
        walletConnectCoordinator.openSession(url: url)
    }

    func processRestartQueueAndRestartUI(reason: RestartReason) {
        restartHandler.processRestartQueueBeforeRestart()
        restartUI(withReason: reason, account: wallet)
    }

    private func restartUI(withReason reason: RestartReason, account: Wallet) {
        delegate?.didRestart(in: self, reason: reason, wallet: account)
    }

    func showWalletQrCode() {
        showTab(.tokens)
        if let nc = tabBarController.viewControllers?.first as? UINavigationController, nc.visibleViewController is RequestViewController {
            //no-op
        } else if navigationController.visibleViewController is RequestViewController {
            //no-op
        } else {
            showPaymentFlow(for: .request, server: config.anyEnabledServer(), navigationController: navigationController)
        }
    }
}

extension ActiveWalletCoordinator: SelectServiceToBuyCryptoCoordinatorDelegate {
    func selectBuyService(_ result: Swift.Result<Void, BuyCryptoError>, in coordinator: SelectServiceToBuyCryptoCoordinator) {
        removeCoordinator(coordinator)

        switch result {
        case .success: break
        case .failure(let error): show(error: error)
        }
    }

    func didClose(in coordinator: SelectServiceToBuyCryptoCoordinator) {
        removeCoordinator(coordinator)
    }

    private func buyCrypto(wallet: Wallet, token: TokenActionsIdentifiable, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        guard let buyTokenProvider = tokenActionsService.service(ofType: BuyTokenProvider.self) as? BuyTokenProvider else { return }
        let coordinator = SelectServiceToBuyCryptoCoordinator(buyTokenProvider: buyTokenProvider, token: token, viewController: viewController, source: source, analytics: analytics)
        coordinator.delegate = self
        coordinator.start(wallet: wallet)
        addCoordinator(coordinator)
    }
}

// swiftlint:enable type_body_length
extension ActiveWalletCoordinator: WalletConnectCoordinatorDelegate {

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        let token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        buyCrypto(wallet: wallet, token: token, viewController: viewController, source: source)
    }

    func requestSwitchChain(server: RPCServer,
                            currentUrl: URL?,
                            targetChain: WalletSwitchEthereumChainObject) -> AnyPublisher<SwitchExistingChainOperation, PromiseError> {

        let coordinator = DappRequestSwitchExistingChainCoordinator(
            config: config,
            server: server,
            targetChain: targetChain,
            restartHandler: restartHandler,
            analytics: analytics,
            currentUrl: currentUrl,
            inViewController: presentationViewController)

        addCoordinator(coordinator)

        return coordinator.start()
            .handleEvents(receiveOutput: { [weak self] operation in
                switch operation {
                case .restartToEnableAndSwitchBrowserToServer:
                    self?.processRestartQueueAndRestartUI(reason: .serverChange)
                case .switchBrowserToExistingServer, .notifySuccessful:
                    break
                }
            }, receiveCompletion: { [weak self] _ in
                self?.removeCoordinator(coordinator)
            }, receiveCancel: { [weak self] in
                self?.removeCoordinator(coordinator)
            }).eraseToAnyPublisher()
    }

    func requestAddCustomChain(server: RPCServer,
                               customChain: WalletAddEthereumChainObject) -> AnyPublisher<SwitchCustomChainOperation, PromiseError> {

        let coordinator = DappRequestSwitchCustomChainCoordinator(
            config: config,
            server: server,
            customChain: customChain,
            restartHandler: restartHandler,
            analytics: analytics,
            currentUrl: nil,
            viewController: presentationViewController,
            networkService: networkService)

        addCoordinator(coordinator)

        return coordinator.start()
            .handleEvents(receiveOutput: { [weak self] operation in
                switch operation {
                case .notifySuccessful:
                    break
                case .restartToEnableAndSwitchBrowserToServer, .restartToAddEnableAndSwitchBrowserToServer:
                    self?.processRestartQueueAndRestartUI(reason: .serverChange)
                case .switchBrowserToExistingServer(let server, url: let url):
                    self?.dappBrowserCoordinator?.switch(toServer: server, url: url)
                }
            }, receiveCompletion: { [weak self] _ in
                self?.removeCoordinator(coordinator)
            }, receiveCancel: { [weak self] in
                self?.removeCoordinator(coordinator)
            }).eraseToAnyPublisher()
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func universalScannerSelected(in coordinator: WalletConnectCoordinator) {
        tokensCoordinator?.launchUniversalScanner(fromSource: .walletScreen)
    }
}

extension ActiveWalletCoordinator: CanOpenURL {
    private func open(url: URL, in viewController: UIViewController) {
        //TODO duplication of code to set up a BrowserCoordinator when creating the application's tabbar
        let browserCoordinator = createBrowserCoordinator(browserOnly: true)
        let controller = browserCoordinator.navigationController
        browserCoordinator.open(url: url, animated: false)
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        if contract == Constants.nativeCryptoAddressInDatabase {
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

extension ActiveWalletCoordinator: TransactionsCoordinatorDelegate {
}

extension ActiveWalletCoordinator: ConsoleCoordinatorDelegate {
    func didCancel(in coordinator: ConsoleCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension ActiveWalletCoordinator: SettingsCoordinatorDelegate {

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

    func didPressShowWallet(in coordinator: SettingsCoordinator) {
        //We are only showing the QR code and some text for this address. Maybe have to rework graphic design so that server isn't necessary
        showPaymentFlow(for: .request, server: config.anyEnabledServer(), navigationController: coordinator.navigationController)
        delegate?.didShowWallet(in: self)
    }

    func restartToReloadServersQueued(in coordinator: SettingsCoordinator) {
        processRestartQueueAndRestartUI(reason: .serverChange)
    }
}

extension ActiveWalletCoordinator: UrlSchemeResolver {

    func openURLInBrowser(url: URL) {
        guard let dappBrowserCoordinator = dappBrowserCoordinator else { return }
        showTab(.browser)
        dappBrowserCoordinator.open(url: url, animated: true)
    }
}

extension ActiveWalletCoordinator: ActivityViewControllerDelegate {

    func requestSignMessage(message: SignMessageType,
                            server: RPCServer,
                            account: AlphaWallet.Address,
                            source: Analytics.SignMessageRequestSource,
                            requester: RequesterViewModel?) -> AnyPublisher<Data, PromiseError> {

        infoLog("[\(source)] signMessage: \(message)")

        return SignMessageCoordinator.promise(
            analytics: analytics,
            navigationController: navigationController,
            keystore: keystore,
            coordinator: self,
            signType: message,
            account: account,
            source: source,
            requester: requester)
            .publisher(queue: .main)
    }

    func reinject(viewController: ActivityViewController) {
        activitiesPipeLine.reinject(activity: viewController.viewModel.activity)
    }

    func goToToken(viewController: ActivityViewController) {
        let token = viewController.viewModel.activity.token
        guard let tokensCoordinator = tokensCoordinator, let navigationController = viewController.navigationController else { return }

        tokensCoordinator.showSingleChainToken(token: token, in: navigationController)
    }

    func speedupTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController) {
        guard let transaction = transactionsDataStore.transaction(withTransactionId: transactionId, forServer: server) else { return }
        guard let session = sessionsProvider.session(for: transaction.server) else { return }
        guard let coordinator = ReplaceTransactionCoordinator(
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            keystore: keystore,
            presentingViewController: viewController,
            session: session,
            transaction: transaction,
            mode: .speedup,
            assetDefinitionStore: assetDefinitionStore,
            tokensService: tokenCollection,
            networkService: networkService) else { return }

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func cancelTransaction(transactionId: String, server: RPCServer, viewController: ActivityViewController) {
        guard let transaction = transactionsDataStore.transaction(withTransactionId: transactionId, forServer: server) else { return }
        guard let session = sessionsProvider.session(for: transaction.server) else { return }
        guard let coordinator = ReplaceTransactionCoordinator(
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            keystore: keystore,
            presentingViewController: viewController,
            session: session,
            transaction: transaction,
            mode: .cancel,
            assetDefinitionStore: assetDefinitionStore,
            tokensService: tokenCollection,
            networkService: networkService) else { return }

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

extension ActiveWalletCoordinator: UITabBarControllerDelegate {

    private func isViewControllerDappBrowserTab(_ viewController: UIViewController) -> Bool {
        guard let dappBrowserCoordinator = dappBrowserCoordinator else { return false }
        return dappBrowserCoordinator.rootViewController.navigationController == viewController
    }

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

extension ActiveWalletCoordinator: TokensCoordinatorDelegate {

    func viewWillAppearOnce(in coordinator: TokensCoordinator) {
        tokenCollection.refreshBalance(updatePolicy: .all)
        activitiesPipeLine.start()
    }

    func blockieSelected(in coordinator: TokensCoordinator) {
        delegate?.showWallets(in: self)
    }

    private func showActivity(_ activity: Activity, navigationController: UINavigationController) {
        let controller = ActivityViewController(
            wallet: wallet,
            assetDefinitionStore: assetDefinitionStore,
            viewModel: .init(activity: activity, tokenImageFetcher: tokenImageFetcher),
            service: activitiesPipeLine,
            tokenImageFetcher: tokenImageFetcher)

        controller.delegate = self

        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    func didTap(activity: Activity, viewController: UIViewController, in coordinator: TokensCoordinator) {
        guard let navigationController = viewController.navigationController else { return }

        showActivity(activity, navigationController: navigationController)
    }

    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: TokensCoordinator) {
        do {
            switch swapTokenFlow {
            case .swapToken(let token):
                try swapToken(token: token)
            case .selectTokenToSwap:
                showTokenSelection(for: .swapToken)
            }
        } catch {
            show(error: error)
        }
    }

    private func showTokenSelection(for operation: PendingOperation) {
        self.pendingOperation = operation

        let coordinator = SelectTokenCoordinator(
            tokenCollection: tokenCollection,
            tokensFilter: tokensFilter,
            navigationController: navigationController,
            filter: .filter(NativeCryptoOrErc20TokenFilter()),
            tokenImageFetcher: tokenImageFetcher)

        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    private func swapToken(token: Token) throws {
        guard let swapTokenProvider = tokenActionsService.service(ofType: SwapTokenProvider.self) as? SwapTokenProvider else {
            throw ActiveWalletError.unavailableToResolveSwapActionProvider
        }

        let coordinator = SelectServiceToSwapCoordinator(
            swapTokenProvider: swapTokenProvider,
            token: token,
            analytics: analytics,
            viewController: navigationController)

        coordinator.delegate = self
        coordinator.start(wallet: wallet)
        addCoordinator(coordinator)
    }

    func didTapBridge(token: Token, service: TokenActionProvider, in coordinator: TokensCoordinator) {
        do {
            guard let service = service as? BridgeTokenURLProviderType else {
                throw ActiveWalletError.unavailableToResolveBridgeActionProvider
            }
            guard let url = service.url(token: token, wallet: wallet) else {
                throw ActiveWalletError.bridgeNotSupported
            }

            open(url: url, onServer: token.server)
        } catch {
            show(error: error)
        }
    }

    func didTapBuy(token: Token, service: TokenActionProvider, in coordinator: TokensCoordinator) {
        buyCrypto(wallet: wallet, token: token, viewController: navigationController, source: .token)
    }

    private func open(for url: URL) {
        guard let dappBrowserCoordinator = dappBrowserCoordinator else { return }
        showTab(.browser)
        dappBrowserCoordinator.open(url: url, animated: true)
    }

    private func open(url: URL, onServer server: RPCServer) {
        //Server shouldn't be disabled since the action is selected
        guard let dappBrowserCoordinator = dappBrowserCoordinator, config.enabledServers.contains(server) else { return }
        showTab(.browser)
        dappBrowserCoordinator.switch(toServer: server, url: url)
    }

    func didTap(suggestedPaymentFlow: SuggestedPaymentFlow, viewController: UIViewController?, in coordinator: TokensCoordinator) {
        let navigationController: UINavigationController
        if let nvc = viewController?.navigationController {
            navigationController = nvc
        } else {
            navigationController = coordinator.navigationController
        }

        switch suggestedPaymentFlow {
        case .payment(let type, let server):
            showPaymentFlow(for: type, server: server, navigationController: navigationController)
        case .other(let action):
            switch action {
            case .sendToRecipient(let recipient):
                showTokenSelection(for: .sendToken(recipient: recipient))
            }
        }
    }

    func didTap(transaction: TransactionInstance, viewController: UIViewController, in coordinator: TokensCoordinator) {
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

    func didSentTransaction(transaction: SentTransaction, in coordinator: TokensCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func didSelectAccount(account: Wallet, in coordinator: TokensCoordinator) {
        guard self.wallet != account else { return }
        restartUI(withReason: .walletChange, account: account)
    }
}

extension ActiveWalletCoordinator: SelectTokenCoordinatorDelegate {
    func coordinator(_ coordinator: SelectTokenCoordinator, didSelectToken token: Token) {
        removeCoordinator(coordinator)

        do {
            guard let operation = pendingOperation else { throw ActiveWalletError.operationForTokenNotFound }

            switch operation {
            case .swapToken:
                try swapToken(token: token)
            case .sendToken(let recipient):
                let paymentFlow = PaymentFlow.send(type: .transaction(.init(fungibleToken: token, recipient: recipient, amount: .notSet)))
                showPaymentFlow(for: paymentFlow, server: token.server, navigationController: navigationController)
            }
        } catch {
            show(error: error)
        }
    }

    func didCancel(in coordinator: SelectTokenCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension ActiveWalletCoordinator: SelectServiceToSwapCoordinatorDelegate {
    func selectSwapService(_ result: Swift.Result<SwapTokenUsing, SwapTokenError>, in coordinator: SelectServiceToSwapCoordinator) {
        removeCoordinator(coordinator)

        switch result {
        case .success(let swapTokenUsing):
            switch swapTokenUsing {
            case .url(let url, let server):
                if let server = server {
                    open(url: url, onServer: server)
                } else {
                    open(for: url)
                }
            case .native(let swapPair):
                showPaymentFlow(for: .swap(pair: swapPair), server: swapPair.from.server, navigationController: navigationController)
            }
        case .failure(let error):
            show(error: error)
        }
    }

    func didClose(in coordinator: SelectServiceToSwapCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension ActiveWalletCoordinator: PaymentCoordinatorDelegate {
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: PaymentCoordinator) {
        guard let coordinator = coordinatorOfType(type: NFTCollectionCoordinator.self) else { return }

        coordinator.showNftAsset(tokenHolder: tokenHolder, mode: .preview)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: PaymentCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator) {
        coordinator.dismiss(animated: true)
        removeCoordinator(coordinator)
        askUserToRateAppOrSubscribeToNewsletter()
    }

    //NOTE: askUserToRateAppOrSubscribeToNewsletter can't be called ringht in confirmation coordinator as after successfully sent transaction coordinator dismissed
    private func askUserToRateAppOrSubscribeToNewsletter() {
        let hostViewController = UIApplication.shared.presentedViewController(or: navigationController)
        let coordinator = HelpUsCoordinator(hostViewController: hostViewController, appTracker: appTracker, analytics: analytics)
        coordinator.rateUsOrSubscribeToNewsletter()
    }

    func didCancel(in coordinator: PaymentCoordinator) {
        coordinator.dismiss(animated: true)

        removeCoordinator(coordinator)
    }
}

extension ActiveWalletCoordinator: DappBrowserCoordinatorDelegate {

    func requestSignTransaction(session: WalletSession,
                                source: Analytics.TransactionConfirmationSource,
                                requester: RequesterViewModel?,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<Data, PromiseError> {

        infoLog("[\(source)] signTransaction: \(transaction) type: \(configuration.confirmType)")

        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, transaction: transaction, configuration: configuration, analytics: analytics, domainResolutionService: domainResolutionService, source: source, delegate: self, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: tokenCollection, networkService: networkService)
        }.map { data -> Data in
            switch data {
            case .signedTransaction(let data):
                return data
            case .sentRawTransaction, .sentTransaction:
                throw PMKError.cancelled
            }
        }.publisher(queue: .main)
    }

    func requestSendRawTransaction(session: WalletSession,
                                   source: Analytics.TransactionConfirmationSource,
                                   requester: DappRequesterViewModel?,
                                   transaction: String) -> AnyPublisher<String, PromiseError> {

        infoLog("[\(source)] signRawTransaction: \(transaction)")
        return firstly {
            showAskSendRawTransaction(title: R.string.localizable.walletConnectSendRawTransactionTitle(), message: transaction)
        }.then { shouldSend -> Promise<ConfirmResult> in
            guard shouldSend else { return .init(error: JsonRpcError.requestRejected) }
            let prompt = R.string.localizable.keystoreAccessKeySign()
            let sender = SendTransaction(session: session, keystore: self.keystore, confirmType: .signThenSend, config: session.config, analytics: self.analytics, prompt: prompt)
            return Promise {
                try await sender.send(rawTransaction: transaction)
            }
        }.map { data in
            switch data {
            case .signedTransaction, .sentTransaction:
                throw JsonRpcError.requestRejected
            case .sentRawTransaction(let transactionId, _):
                return transactionId
            }
        }.then { callback -> Promise<String> in
            return UINotificationFeedbackGenerator.showFeedbackPromise(value: callback, feedbackType: .success)
        }.get { _ in
            TransactionInProgressCoordinator.promise(self.navigationController, coordinator: self).done { _ in }.cauterize()
        }.publisher(queue: .main)
    }

    private func showAskSendRawTransaction(title: String, message: String) -> Promise<Bool> {
        return Promise { seal in
            let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet

            let alertViewController = UIAlertController(title: title, message: message, preferredStyle: style)
            let startAction = UIAlertAction(title: R.string.localizable.oK(), style: .default) { _ in
                seal.fulfill(true)
            }

            let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
                seal.fulfill(false)
            }

            alertViewController.addAction(startAction)
            alertViewController.addAction(cancelAction)

            navigationController.present(alertViewController, animated: true)
        }
    }

    func requestSendTransaction(session: WalletSession,
                                source: Analytics.TransactionConfirmationSource,
                                requester: RequesterViewModel?,
                                transaction: UnconfirmedTransaction,
                                configuration: TransactionType.Configuration) -> AnyPublisher<SentTransaction, PromiseError> {

        infoLog("[\(source)] sendTransaction: \(transaction) type: \(configuration.confirmType)")

        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: session, coordinator: self, transaction: transaction, configuration: configuration, analytics: analytics, domainResolutionService: domainResolutionService, source: .walletConnect, delegate: self, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: tokenCollection, networkService: networkService)
        }.map { data -> SentTransaction in
            switch data {
            case .sentTransaction(let transaction):
                return transaction
            case .signedTransaction, .sentRawTransaction:
                throw PMKError.cancelled
            }
        }.get { _ in
            TransactionInProgressCoordinator.promise(self.navigationController, coordinator: self).done { _ in }.cauterize()
        }.publisher(queue: .main)
    }

    func requestGetTransactionCount(session: WalletSession, source: Analytics.SignMessageRequestSource) -> AnyPublisher<Data, PromiseError> {
        infoLog("[\(source)] getTransactionCount")
        return Future { return try await session.blockchainProvider.nonce(wallet: session.account.address) }
            .mapError { PromiseError(error: $0) }
            .flatMap { nonce -> AnyPublisher<Data, PromiseError> in
                if let data = Data(fromHexEncodedString: String(format: "%02X", nonce)) {
                    return .just(data)
                } else {
                    return .fail(PromiseError(error: PMKError.badInput))
                }
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func requestEthCall(from: AlphaWallet.Address?,
                        to: AlphaWallet.Address?,
                        value: String?,
                        data: String,
                        source: Analytics.SignMessageRequestSource,
                        session: WalletSession) -> AnyPublisher<String, PromiseError> {

        infoLog("[\(source)] ethCall")
        return session.blockchainProvider
            .call(from: from, to: to, value: value, data: data)
            .receive(on: RunLoop.main)
            .mapError { PromiseError(error: $0.unwrapped) }
            .eraseToAnyPublisher()
    }

    func didSentTransaction(transaction: SentTransaction, inCoordinator coordinator: DappBrowserCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: DappBrowserCoordinator) {
        delegate?.handleUniversalLink(url, forCoordinator: self, source: .dappBrowser)
    }

    func restartToAddEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappBrowserCoordinator) {
        processRestartQueueAndRestartUI(reason: .serverChange)
    }

    func restartToEnableAndSwitchBrowserToServer(inCoordinator coordinator: DappBrowserCoordinator) {
        processRestartQueueAndRestartUI(reason: .serverChange)
    }
}

extension ActiveWalletCoordinator: StaticHTMLViewControllerDelegate {
}

extension ActiveWalletCoordinator: ActivitiesCoordinatorDelegate {

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

// MARK: Analytics
extension ActiveWalletCoordinator {
    private func logEnabledChains() {
        let list = config.enabledServers.map(\.chainID).sorted()
        analytics.setUser(property: Analytics.UserProperties.enabledChains, value: list)
    }

    private func logWallets() {
        let totalCount = keystore.wallets.count
        let hdWalletsCount = keystore.wallets.filter { $0.origin == .hd }.count
        let keystoreWalletsCount = keystore.wallets.filter { $0.origin == .privateKey }.count
        let watchedWalletsCount = keystore.wallets.filter { $0.origin == .watch }.count
        analytics.setUser(property: Analytics.UserProperties.walletsCount, value: totalCount)
        analytics.setUser(property: Analytics.UserProperties.hdWalletsCount, value: hdWalletsCount)
        analytics.setUser(property: Analytics.UserProperties.keystoreWalletsCount, value: keystoreWalletsCount)
        analytics.setUser(property: Analytics.UserProperties.watchedWalletsCount, value: watchedWalletsCount)
    }

    private func logDynamicTypeSetting() {
        let setting = UIApplication.shared.preferredContentSizeCategory.rawValue
        analytics.setUser(property: Analytics.UserProperties.dynamicTypeSetting, value: setting)
    }

    private func logIsAppPasscodeOrBiometricProtectionEnabled() {
        let isOn = lock.isPasscodeSet
        analytics.setUser(property: Analytics.UserProperties.isAppPasscodeOrBiometricProtectionEnabled, value: isOn)
    }

    private func logExplorerUse(type: Analytics.ExplorerType) {
        analytics.log(navigation: Analytics.Navigation.explorer, properties: [Analytics.Properties.type.rawValue: type.rawValue])
    }
}

extension ActiveWalletCoordinator: ReplaceTransactionCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: ReplaceTransactionCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: ReplaceTransactionCoordinator) {
        removeCoordinator(coordinator)
        askUserToRateAppOrSubscribeToNewsletter()
    }
}

extension ActiveWalletCoordinator: WhatsNewExperimentCoordinatorDelegate {
    func didEnd(in coordinator: WhatsNewExperimentCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension ActiveWalletCoordinator: LoadUrlInDappBrowserProvider {
    func didLoadUrlInDappBrowser(url: URL, in handler: RestartQueueHandler) {
        showTab(.browser)
        dappBrowserCoordinator?.open(url: url, animated: false)
    }
}

extension ActiveWalletCoordinator: BlockscanChatServiceDelegate {
    func openBlockscanChat(url: URL, for: BlockscanChatService) {
        analytics.log(navigation: Analytics.Navigation.blockscanChat)
        open(for: url)
    }

    func showBlockscanUnreadCount(_ count: Int?, for: BlockscanChatService) {
        settingsCoordinator?.showBlockscanChatUnreadCount(count)
    }
}

extension ActiveWalletCoordinator: WalletPupupCoordinatorDelegate {
    func didSelect(action: PupupAction, in coordinator: WalletPupupCoordinator) {
        removeCoordinator(coordinator)

        let server = config.anyEnabledServer()
        switch action {
        case .swap:
            showTokenSelection(for: .swapToken)
        case .buy:
            buyCrypto(wallet: wallet, server: server, viewController: navigationController, source: .walletTab)
        case .receive:
            showPaymentFlow(for: .request, server: server, navigationController: navigationController)
        case .send:
            showTokenSelection(for: .sendToken(recipient: nil))
        }
    }

    func didClose(in coordinator: WalletPupupCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension ActiveWalletCoordinator {

    enum PendingOperation {
        case swapToken
        case sendToken(recipient: AddressOrEnsName?)
    }
}
// swiftlint:enable file_length
