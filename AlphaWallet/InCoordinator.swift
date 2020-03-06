// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import RealmSwift
import BigInt

protocol InCoordinatorDelegate: class {
    func didCancel(in coordinator: InCoordinator)
    func didUpdateAccounts(in coordinator: InCoordinator)
    func didShowWallet(in coordinator: InCoordinator)
    func assetDefinitionsOverrideViewController(for coordinator: InCoordinator) -> UIViewController?
    func importUniversalLink(url: URL, forCoordinator coordinator: InCoordinator)
}

enum Tabs {
    case wallet
    case alphaWalletSettings
    case transactions

    var className: String {
        switch self {
        case .wallet:
            return String(describing: TokensViewController.self)
        case .transactions:
            return String(describing: TransactionsViewController.self)
        case .alphaWalletSettings:
            return String(describing: SettingsViewController.self)
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
    private var callForAssetAttributeCoordinators = ServerDictionary<CallForAssetAttributeCoordinator>() {
        didSet {
            XMLHandler.callForAssetAttributeCoordinators = callForAssetAttributeCoordinators
        }
    }
    //TODO We might not need this anymore once we stop using the vendored Web3Swift library which uses a WKWebView underneath
    private var claimOrderCoordinator: ClaimOrderCoordinator?
    var tokensStorages = ServerDictionary<TokensDataStore>()
    lazy var nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>> = {
        return createEtherPricesSubscribablesForAllChains()
    }()
    lazy var nativeCryptoCurrencyBalances: ServerDictionary<Subscribable<BigInt>> = {
        return createEtherBalancesSubscribablesForAllChains()
    }()
    private var transactionCoordinator: TransactionCoordinator? {
        return coordinators.compactMap {
            $0 as? TransactionCoordinator
        }.first
    }
    private var tokensCoordinator: TokensCoordinator? {
        return coordinators.compactMap { $0 as? TokensCoordinator }.first
    }
    private var dappBrowserCoordinator: DappBrowserCoordinator? {
        return coordinators.compactMap { $0 as? DappBrowserCoordinator }.first
    }

    private lazy var helpUsCoordinator: HelpUsCoordinator = {
        return HelpUsCoordinator(
                navigationController: navigationController,
                appTracker: appTracker
        )
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var keystore: Keystore
    weak var delegate: InCoordinatorDelegate?
    var tabBarController: UITabBarController? {
        return navigationController.viewControllers.first as? UITabBarController
    }

    init(
            navigationController: UINavigationController = NavigationController(),
            wallet: Wallet,
            keystore: Keystore,
            assetDefinitionStore: AssetDefinitionStore,
            config: Config,
            appTracker: AppTracker = AppTracker()
    ) {
        self.navigationController = navigationController
        self.wallet = wallet
        self.keystore = keystore
        self.config = config
        self.appTracker = appTracker
        self.assetDefinitionStore = assetDefinitionStore
        self.assetDefinitionStore.enableFetchXMLForContractInPasteboard()

        super.init()
    }

    func start() {
        showTabBar(for: wallet)
        checkDevice()

        helpUsCoordinator.start()
        addCoordinator(helpUsCoordinator)
        fetchXMLAssetDefinitions()
        listOfBadTokenScriptFilesChanged(fileNames: assetDefinitionStore.listOfBadTokenScriptFiles + assetDefinitionStore.conflictingTokenScriptFileNames.all)
    }

    private func createTokensDatastore(forConfig config: Config, server: RPCServer) -> TokensDataStore {
        let realm = self.realm(forAccount: wallet)
        return TokensDataStore(realm: realm, account: wallet, server: server, config: config, assetDefinitionStore: assetDefinitionStore)
    }

    private func createTransactionsStorage(server: RPCServer) -> TransactionsStorage {
        let realm = self.realm(forAccount: wallet)
        return TransactionsStorage(realm: realm, server: server, delegate: self)
    }

    private func fetchCryptoPrice(forServer server: RPCServer) {
        assert(!tokensStorages.isEmpty)

        let tokensStorage = tokensStorages[server]
        let etherToken = TokensDataStore.etherToken(forServer: server)
        tokensStorage.tokensModel.subscribe {[weak self, weak tokensStorage] tokensModel in
            guard let strongSelf = self else { return }
            guard let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else { return }
            guard let tokensStorage = tokensStorage else { return }
            if let ticker = tokensStorage.coinTicker(for: eth) {
                strongSelf.nativeCryptoCurrencyPrices[server].value = Double(ticker.price_usd)
            } else {
                tokensStorage.updatePricesAfterComingOnline()
            }
        }
    }

    private func oneTimeCreationOfOneDatabaseToHoldAllChains() {
        let migration = MigrationInitializer(account: wallet)
        //Debugging
        print(migration.config.fileURL!)
        print(migration.config.fileURL!.deletingLastPathComponent())
        let exists: Bool
        if let path = migration.config.fileURL?.path {
            exists = FileManager.default.fileExists(atPath: path)
        } else {
            exists = false
        }
        guard !exists else { return }

        migration.perform()
        let realm = try! Realm(configuration: migration.config)
        do {
            try realm.write {
                for each in RPCServer.allCases {
                    let migration = MigrationInitializerForOneChainPerDatabase(account: wallet, server: each, assetDefinitionStore: assetDefinitionStore)
                    migration.perform()
                    let oldPerChainDatabase = try! Realm(configuration: migration.config)
                    for each in oldPerChainDatabase.objects(Bookmark.self) {
                        realm.create(Bookmark.self, value: each)
                    }
                    for each in oldPerChainDatabase.objects(DelegateContract.self) {
                        realm.create(DelegateContract.self, value: each)
                    }
                    for each in oldPerChainDatabase.objects(DeletedContract.self) {
                        realm.create(DeletedContract.self, value: each)
                    }
                    for each in oldPerChainDatabase.objects(HiddenContract.self) {
                        realm.create(HiddenContract.self, value: each)
                    }
                    for each in oldPerChainDatabase.objects(History.self) {
                        realm.create(History.self, value: each)
                    }
                    for each in oldPerChainDatabase.objects(TokenObject.self) {
                        realm.create(TokenObject.self, value: each)
                    }
                    for each in oldPerChainDatabase.objects(Transaction.self) {
                        realm.create(Transaction.self, value: each)
                    }
                }
            }
            for each in RPCServer.allCases {
                let migration = MigrationInitializerForOneChainPerDatabase(account: wallet, server: each, assetDefinitionStore: assetDefinitionStore)
                let realmUrl = migration.config.fileURL!
                let realmUrls = [
                    realmUrl,
                    realmUrl.appendingPathExtension("lock"),
                    realmUrl.appendingPathExtension("note"),
                    realmUrl.appendingPathExtension("management")
                ]
                for each in realmUrls {
                    try? FileManager.default.removeItem(at: each)
                }
            }
        } catch {
            //no-op
        }
    }

    private func setupCallForAssetAttributeCoordinators() {
        callForAssetAttributeCoordinators = .init()
        for each in RPCServer.allCases {
            let session = walletSessions[each]
            callForAssetAttributeCoordinators[each] = CallForAssetAttributeCoordinator(server: each, session: session, assetDefinitionStore: self.assetDefinitionStore)
        }
    }

    private func setupTokenDataStores() {
        tokensStorages = .init()
        for each in RPCServer.allCases {
            let tokensStorage = createTokensDatastore(forConfig: config, server: each)
            tokensStorages[each] = tokensStorage
        }
    }

    private func setupTransactionsStorages() {
        transactionsStorages = .init()
        for each in RPCServer.allCases {
            let transactionsStorage = createTransactionsStorage(server: each)
            transactionsStorage.removeTransactions(for: [.failed, .pending, .unknown])
            transactionsStorages[each] = transactionsStorage
        }
    }

    private func setupEtherBalances() {
        nativeCryptoCurrencyBalances = .init()
        for each in RPCServer.allCases {
            let price = createCryptoCurrencyBalanceSubscribable(forServer: each)
            let tokensStorage = tokensStorages[each]
            let etherToken = TokensDataStore.etherToken(forServer: each)
            tokensStorage.tokensModel.subscribe {[weak self] tokensModel in
                guard let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else {
                    return
                }
                if let balance = BigInt(eth.value) {
                    guard let strongSelf = self else { return }
                    strongSelf.nativeCryptoCurrencyBalances[each].value = BigInt(eth.value)
                    guard !(balance.isZero) else { return }
                    //TODO we don'backup wallets if we are running tests. Maybe better to move this into app delegate's application(_:didFinishLaunchingWithOptions:)
                    guard !isRunningTests() else { return }
                }
            }
            nativeCryptoCurrencyBalances[each] = price
        }
    }

    private func setupWalletSessions() {
        walletSessions = .init()
        for each in RPCServer.allCases {
            let tokensStorage = tokensStorages[each]
            let session = WalletSession(
                    account: wallet,
                    server: each,
                    config: config,
                    tokensDataStore: tokensStorage
            )
            walletSessions[each] = session
        }
    }

    //Setup functions has to be called in the right order as they may rely on eg. wallet sessions being available. Wrong order should be immediately apparent with crash on startup. So don't worry
    private func setupResourcesOnMultiChain() {
        oneTimeCreationOfOneDatabaseToHoldAllChains()
        setupTokenDataStores()
        setupTransactionsStorages()
        setupEtherBalances()
        setupWalletSessions()
        setupCallForAssetAttributeCoordinators()
    }

    func showTabBar(for account: Wallet) {
        keystore.recentlyUsedWallet = account
        wallet = account

        setupResourcesOnMultiChain()

        //TODO creating many objects here. Messy. Improve?
        let realm = self.realm(forAccount: wallet)
        let tabBarController = createTabBarController(realm: realm)

        navigationController.setViewControllers(
                [tabBarController],
                animated: false
        )
        navigationController.setNavigationBarHidden(true, animated: false)

        let inCoordinatorViewModel = InCoordinatorViewModel()
        showTab(inCoordinatorViewModel.initialTab)
    }

    private func createTokensCoordinator(promptBackupCoordinator: PromptBackupCoordinator) -> TokensCoordinator {
        let tokensStoragesForEnabledServers = config.enabledServers.map { tokensStorages[$0] }
        let tokenCollection = TokenCollection(assetDefinitionStore: assetDefinitionStore, tokenDataStores: tokensStoragesForEnabledServers)
        promptBackupCoordinator.listenToNativeCryptoCurrencyBalance(withTokenCollection: tokenCollection)
        let coordinator = TokensCoordinator(
                sessions: walletSessions,
                keystore: keystore,
                config: config,
                tokenCollection: tokenCollection,
                nativeCryptoCurrencyPrices: nativeCryptoCurrencyPrices,
                assetDefinitionStore: assetDefinitionStore,
                promptBackupCoordinator: promptBackupCoordinator
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

    private func createBrowserCoordinator(sessions: ServerDictionary<WalletSession>, realm: Realm, browserOnly: Bool) -> DappBrowserCoordinator {
        let coordinator = DappBrowserCoordinator(sessions: sessions, keystore: keystore, config: config, sharedRealm: realm, browserOnly: browserOnly)
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
                promptBackupCoordinator: promptBackupCoordinator
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.aSettingsNavigationTitle(), image: R.image.tab_settings(), selectedImage: nil)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    //TODO do we need 2 separate TokensDataStore instances? Is it because they have different delegates?
    private func createTabBarController(realm: Realm) -> UITabBarController {
        var viewControllers = [UIViewController]()

        let promptBackupCoordinator = PromptBackupCoordinator(keystore: keystore, wallet: wallet, config: config)
        addCoordinator(promptBackupCoordinator)

        let tokensCoordinator = createTokensCoordinator(promptBackupCoordinator: promptBackupCoordinator)
        configureNavigationControllerForLargeTitles(tokensCoordinator.navigationController)
        viewControllers.append(tokensCoordinator.navigationController)

        let transactionCoordinator = createTransactionCoordinator(promptBackupCoordinator: promptBackupCoordinator)
        configureNavigationControllerForLargeTitles(transactionCoordinator.navigationController)
        viewControllers.append(transactionCoordinator.navigationController)

        let browserCoordinator = createBrowserCoordinator(sessions: walletSessions, realm: realm, browserOnly: false)
        viewControllers.append(browserCoordinator.navigationController)

        let settingsCoordinator = createSettingsCoordinator(keystore: keystore, promptBackupCoordinator: promptBackupCoordinator)
        configureNavigationControllerForLargeTitles(settingsCoordinator.navigationController)
        viewControllers.append(settingsCoordinator.navigationController)

        let tabBarController = TabBarController()
        tabBarController.tabBar.isTranslucent = false
        tabBarController.viewControllers = viewControllers
        tabBarController.delegate = self

        promptBackupCoordinator.start()

        return tabBarController
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
        guard let viewControllers = tabBarController?.viewControllers else {
            return
        }
        for controller in viewControllers {
            if let nav = controller as? UINavigationController {
                if nav.viewControllers[0].className == selectTab.className {
                    tabBarController?.selectedViewController = nav
                }
            }
        }
    }

    private func restart(for account: Wallet, in coordinator: TransactionCoordinator) {
        navigationController.dismiss(animated: false, completion: nil)
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        coordinator.stop()
        removeAllCoordinators()
        OpenSea.resetInstances()
        showTabBar(for: account)
        fetchXMLAssetDefinitions()
        listOfBadTokenScriptFilesChanged(fileNames: assetDefinitionStore.listOfBadTokenScriptFiles + assetDefinitionStore.conflictingTokenScriptFileNames.all)
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

    func showPaymentFlow(for type: PaymentFlow, server: RPCServer) {
        let session = walletSessions[server]
        let tokenStorage = tokensStorages[server]

        switch (type, session.account.type) {
        case (.send, .real), (.request, _):
            let coordinator = PaymentCoordinator(
                    flow: type,
                    session: session,
                    keystore: keystore,
                    storage: tokenStorage,
                    ethPrice: nativeCryptoCurrencyPrices[server],
                    assetDefinitionStore: assetDefinitionStore
            )
            coordinator.delegate = self
            coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
            if let topVC = navigationController.presentedViewController {
                topVC.present(coordinator.navigationController, animated: true, completion: nil)
            } else {
                navigationController.present(coordinator.navigationController, animated: true, completion: nil)
            }
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

    private func realm(forAccount account: Wallet) -> Realm {
        let migration = MigrationInitializer(account: account)
        migration.perform()
        return try! Realm(configuration: migration.config)
    }

    private func showTransactionSent(transaction: SentTransaction) {
        let alertController = UIAlertController(title: R.string.localizable.sendActionTransactionSent(), message: R.string.localizable.sendActionTransactionSentWait(), preferredStyle: .alert)
        let copyAction = UIAlertAction(title: R.string.localizable.sendActionCopyTransactionTitle(), style: UIAlertAction.Style.default, handler: { _ in
            UIPasteboard.general.string = transaction.id
        })
        alertController.addAction(copyAction)
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: nil))
        navigationController.present(alertController, animated: true, completion: nil)
    }

    private func fetchXMLAssetDefinitions() {
        let coordinator = FetchAssetDefinitionsCoordinator(assetDefinitionStore: assetDefinitionStore, tokensDataStores: tokensStorages)
        coordinator.start()
        addCoordinator(coordinator)
    }

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void) {
        let server = tokenObject.server
        let signature = signedOrder.signature.substring(from: 2)
        let v = UInt8(signature.substring(from: 128), radix: 16)!
        let r = "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64)))
        let s = "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
        guard let wallet = keystore.recentlyUsedWallet else { return }
        claimOrderCoordinator = ClaimOrderCoordinator()
        claimOrderCoordinator?.claimOrder(
                signedOrder: signedOrder,
                expiry: signedOrder.order.expiry,
                v: v,
                r: r,
                s: s,
                contractAddress: signedOrder.order.contractAddress,
                recipient: wallet.address
        ) { result in
            let strongSelf = self
            switch result {
            case .success(let payload):
                let session = strongSelf.walletSessions[server]
                let account = try! EtherKeystore().getAccount(for: wallet.address)!
                TransactionConfigurator.estimateGasPrice(server: server).done { gasPrice in
                    //Note: since we have the data payload, it is unnecessary to load an UnconfirmedTransaction struct
                    let transactionToSign = UnsignedTransaction(
                            value: BigInt(signedOrder.order.price),
                            account: account,
                            to: signedOrder.order.contractAddress,
                            nonce: -1,
                            data: payload,
                            gasPrice: gasPrice,
                            gasLimit: GasLimitConfiguration.maxGasLimit,
                            server: server
                    )
                    let sendTransactionCoordinator = SendTransactionCoordinator(
                            session: session,
                            keystore: strongSelf.keystore,
                            confirmType: .signThenSend
                    )
                    sendTransactionCoordinator.send(transaction: transactionToSign) { result in
                        switch result {
                        case .success(let res):
                            completion(true)
                            print(res)
                        case .failure(let error):
                            completion(false)
                            print(error)
                        }
                    }
                }
            case .failure: break
            }
        }
    }

    func addImported(contract: AlphaWallet.Address, forServer server: RPCServer) {
        //Useful to check because we are/might action-only TokenScripts for native crypto currency
        guard !contract.sameContract(as: Constants.nativeCryptoAddressInDatabase) else { return }
        let tokensCoordinator = coordinators.first { $0 is TokensCoordinator } as? TokensCoordinator
        tokensCoordinator?.addImportedToken(forContract: contract, server: server)
    }

    private func createEtherPricesSubscribablesForAllChains() -> ServerDictionary<Subscribable<Double>> {
        var result = ServerDictionary<Subscribable<Double>>()
        for each in RPCServer.allCases {
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
        for each in RPCServer.allCases {
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

    func listOfBadTokenScriptFilesChanged(fileNames: [TokenScriptFileIndices.FileName]) {
        tokensCoordinator?.listOfBadTokenScriptFilesChanged(fileNames: fileNames)
    }

    private func showConsole() {
        let viewController = createConsoleViewController()
        viewController.navigationItem.rightBarButtonItem =  .init(barButtonSystemItem: .done, target: viewController, action: #selector(viewController.dismissConsole))
        if let topVC = navigationController.presentedViewController {
            viewController.makePresentationFullScreenForiOS13Migration()
            topVC.present(viewController, animated: true)
        } else {
            let nc = UINavigationController(rootViewController: viewController)
            nc.makePresentationFullScreenForiOS13Migration()
            navigationController.present(nc, animated: true)
        }
    }

    private func createConsoleViewController() -> ConsoleViewController {
        let coordinator = ConsoleCoordinator(assetDefinitionStore: assetDefinitionStore)
        return coordinator.createConsoleViewController()
    }
}
// swiftlint:enable type_body_length

extension InCoordinator: CanOpenURL {
    private func open(url: URL, in viewController: UIViewController) {
        guard let account = keystore.recentlyUsedWallet else { return }

        //TODO duplication of code to set up a BrowserCoordinator when creating the application's tabbar
        let realm = self.realm(forAccount: account)
        let browserCoordinator = createBrowserCoordinator(sessions: walletSessions, realm: realm, browserOnly: true)
        let controller = browserCoordinator.navigationController
        browserCoordinator.open(url: url, animated: false)
        controller.makePresentationFullScreenForiOS13Migration()
        viewController.present(controller, animated: true, completion: nil)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        if contract.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            let url = server.etherscanContractDetailsWebPageURL(for: wallet.address)
            open(url: url, in: viewController)
        } else {
            let url = server.etherscanContractDetailsWebPageURL(for: contract)
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

extension InCoordinator: SettingsCoordinatorDelegate {
    func didCancel(in coordinator: SettingsCoordinator) {
        removeCoordinator(coordinator)
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        delegate?.didCancel(in: self)
    }

    func didRestart(with account: Wallet, in coordinator: SettingsCoordinator) {
        guard let transactionCoordinator = transactionCoordinator else {
            return
        }
        restart(for: account, in: transactionCoordinator)
    }

    func didUpdateAccounts(in coordinator: SettingsCoordinator) {
        delegate?.didUpdateAccounts(in: self)
    }

    func didPressShowWallet(in coordinator: SettingsCoordinator) {
        //We are only showing the QR code and some text for this address. Maybe have to rework graphic design so that server isn't necessary
        showPaymentFlow(for: .request, server: .main)
        delegate?.didShowWallet(in: self)
    }

    func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController? {
        return delegate?.assetDefinitionsOverrideViewController(for: self)
    }

    func consoleViewController(for: SettingsCoordinator) -> UIViewController? {
        return createConsoleViewController()
    }

    func delete(account: Wallet, in coordinator: SettingsCoordinator) {
        let realm = self.realm(forAccount: account)
        for each in RPCServer.allCases {
            let transactionsStorage = TransactionsStorage(realm: realm, server: each, delegate: nil)
            transactionsStorage.deleteAll()
        }
    }
}

extension InCoordinator: TokensCoordinatorDelegate {
    func didPress(for type: PaymentFlow, server: RPCServer, in coordinator: TokensCoordinator) {
        showPaymentFlow(for: type, server: server)
    }

    func didTap(transaction: Transaction, inViewController viewController: UIViewController, in coordinator: TokensCoordinator) {
        transactionCoordinator?.showTransaction(transaction, inViewController: viewController)
    }

    func openConsole(inCoordinator coordinator: TokensCoordinator) {
        showConsole()
    }
}

extension InCoordinator: PaymentCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator) {
        switch result {
        case .sentTransaction(let transaction):
            handlePendingTransaction(transaction: transaction)
            showTransactionSent(transaction: transaction)
            removeCoordinator(coordinator)

            guard let currentTab = tabBarController?.selectedViewController else { return }
            currentTab.dismiss(animated: true)

            // Once transaction sent, show transactions screen.
            showTab(.transactions)
        case .signedTransaction: break
        }
    }

    func didCancel(in coordinator: PaymentCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
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
}

struct NoTokenError: LocalizedError {
    var errorDescription: String? {
        return R.string.localizable.aWalletNoTokens()
    }
}

extension InCoordinator: StaticHTMLViewControllerDelegate {
}

extension InCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if !isViewControllerDappBrowserTab(viewController) {
            dappBrowserCoordinator?.willHide()
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if isViewControllerDappBrowserTab(viewController) {
            dappBrowserCoordinator?.didShow()
        }
    }
}

extension InCoordinator: TransactionsStorageDelegate {
    func didAddTokensWith(contracts: [AlphaWallet.Address], inTransactionsStorage: TransactionsStorage) {
        for each in contracts {
            assetDefinitionStore.fetchXML(forContract: each)
        }
    }
}
