// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit
import RealmSwift
import BigInt

protocol InCoordinatorDelegate: class {
    func didCancel(in coordinator: InCoordinator)
    func didUpdateAccounts(in coordinator: InCoordinator)
    func didShowWallet(in coordinator: InCoordinator)
    func assetDefinitionsOverrideViewController(for coordinator: InCoordinator) -> UIViewController?
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

class InCoordinator: NSObject, Coordinator {
    private var wallet: Wallet
    private let config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    private let appTracker: AppTracker
    private var transactionsStorages = ServerDictionary<TransactionsStorage>()
    private var walletSessions = ServerDictionary<WalletSession>()
    private var tokensStoragesForCryptoPriceFetching = ServerDictionary<TokensDataStore>()
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
    }

    func start() {
        showTabBar(for: wallet)
        checkDevice()

        helpUsCoordinator.start()
        addCoordinator(helpUsCoordinator)
        fetchXMLAssetDefinitions()
    }

    private func createTokensDatastore(forConfig config: Config, server: RPCServer) -> TokensDataStore {
        let realm = self.realm(forAccount: wallet)
        return TokensDataStore(realm: realm, account: wallet, server: server, config: config, assetDefinitionStore: assetDefinitionStore)
    }

    private func createTransactionsStorage(server: RPCServer) -> TransactionsStorage {
        let realm = self.realm(forAccount: wallet)
        return TransactionsStorage(realm: realm, server: server)
    }

    private func fetchCryptoPrice(forServer server: RPCServer) {
        let tokensStorage = createTokensDatastore(forConfig: config, server: server)
        tokensStoragesForCryptoPriceFetching[server] = tokensStorage
        tokensStorage.updatePrices()

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
        print(migration.config.fileURL!.path)
        print(migration.config.fileURL!.deletingLastPathComponent().path)
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
                    let migration = MigrationInitializerForOneChainPerDatabase(account: wallet, server: each)
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
                let migration = MigrationInitializerForOneChainPerDatabase(account: wallet, server: each)
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
            let tokensDataStore = createTokensDatastore(forConfig: config, server: each)
            let callForAssetAttributeCoordinator = CallForAssetAttributeCoordinator(server: each, tokensDataStore: tokensDataStore)
            callForAssetAttributeCoordinators[each] = callForAssetAttributeCoordinator
            //Since this is called at launch, we don't want it to block launching
            DispatchQueue.global().async {
                DispatchQueue.main.async { [weak self] in
                    callForAssetAttributeCoordinator.refreshFunctionCallBasedAssetAttributesForAllTokens()
                }
            }
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
                    guard ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil else { return }
                    strongSelf.promptBackupWallet(withAddress: strongSelf.wallet.address.description)
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

    private func setupResourcesOnMultiChain() {
        oneTimeCreationOfOneDatabaseToHoldAllChains()
        setupCallForAssetAttributeCoordinators()
        setupTokenDataStores()
        setupTransactionsStorages()
        setupEtherBalances()
        setupWalletSessions()
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

    private func createTokensCoordinator() -> TokensCoordinator {
        let tokensStoragesForEnabledServers = config.enabledServers.map { tokensStorages[$0] }
        let tokenCollection = TokenCollection(tokenDataStores: tokensStoragesForEnabledServers)
        let coordinator = TokensCoordinator(
                sessions: walletSessions,
                keystore: keystore,
                tokenCollection: tokenCollection,
                nativeCryptoCurrencyPrices: nativeCryptoCurrencyPrices,
                assetDefinitionStore: assetDefinitionStore
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.tab_wallet())
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createTransactionCoordinator() -> TransactionCoordinator {
        let transactionsStoragesForEnabledServers = config.enabledServers.map { transactionsStorages[$0] }
        let transactionsCollection = TransactionCollection(transactionsStorages: transactionsStoragesForEnabledServers)
        let coordinator = TransactionCoordinator(
                sessions: walletSessions,
                transactionsCollection: transactionsCollection,
                keystore: keystore,
                tokensStorages: tokensStorages
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.transactionsTabbarItemTitle(), image: R.image.feed()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.feed())
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createBrowserCoordinator(sessions: ServerDictionary<WalletSession>, realm: Realm, browserOnly: Bool) -> DappBrowserCoordinator {
        let coordinator = DappBrowserCoordinator(sessions: sessions, keystore: keystore, sharedRealm: realm, browserOnly: browserOnly)
        coordinator.delegate = self
        coordinator.start()
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.browserTabbarItemTitle(), image: R.image.dapps_icon(), selectedImage: nil)
        addCoordinator(coordinator)
        return coordinator
    }

    private func createSettingsCoordinator(keystore: Keystore) -> SettingsCoordinator {
        let coordinator = SettingsCoordinator(
                keystore: keystore,
                config: config,
                sessions: walletSessions
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(
                title: R.string.localizable.aSettingsNavigationTitle(),
                image: R.image.tab_settings()?.withRenderingMode(.alwaysOriginal),
                selectedImage: R.image.tab_settings()
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    //TODO do we need 2 separate TokensDataStore instances? Is it because they have different delegates?
    private func createTabBarController(realm: Realm) -> UITabBarController {
        var viewControllers = [UIViewController]()

        let tokensCoordinator = createTokensCoordinator()
        viewControllers.append(tokensCoordinator.navigationController)

        let transactionCoordinator = createTransactionCoordinator()
        viewControllers.append(transactionCoordinator.navigationController)

        let browserCoordinator = createBrowserCoordinator(sessions: walletSessions, realm: realm, browserOnly: false)
        viewControllers.append(browserCoordinator.navigationController)

        let settingsCoordinator = createSettingsCoordinator(keystore: keystore)
        viewControllers.append(settingsCoordinator.navigationController)

        let tabBarController = TabBarController()
        tabBarController.tabBar.isTranslucent = false
        tabBarController.viewControllers = viewControllers
        tabBarController.delegate = self
        hideTitlesInTabBarController(tabBarController: tabBarController)
        return tabBarController
    }

    private func promptBackupWallet(withAddress address: String) {
        //TODo wallet or Address instead?
        let coordinator = PromptBackupCoordinator(keystore: keystore, walletAddress: address, config: config)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    private func hideTitlesInTabBarController(tabBarController: UITabBarController) {
        guard let items = tabBarController.tabBar.items else { return }
		for each in items {
            if UIDevice.current.userInterfaceIdiom == .phone {
                each.imageInsets = UIEdgeInsets(top: 6, left: 0, bottom: -6, right: 0)
            }
			each.title = ""
        }
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
        OpenSea.sharedInstance.reset()
        showTabBar(for: account)
        fetchXMLAssetDefinitions()
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
                    ethPrice: nativeCryptoCurrencyPrices[server]
            )
            coordinator.delegate = self
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

    private func web3(forServer server: RPCServer) -> Web3Swift {
        return Web3Swift(url: server.rpcURL)
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

    // When a user clicks a Universal Link, either the user pays to publish a
    // transaction or, if the token price = 0 (new purchase or incoming
    // transfer from a buddy), the user can send the data to a paymaster.
    // This function deal with the special case that the token price = 0
    // but not sent to the paymaster because the user has ether.
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void) {
        let server = tokenObject.server
        let web3 = self.web3(forServer: server)
        web3.start()
        let signature = signedOrder.signature.substring(from: 2)
        let v = UInt8(signature.substring(from: 128), radix: 16)!
        let r = "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64)))
        let s = "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
        guard let wallet = keystore.recentlyUsedWallet else { return }

        claimOrderCoordinator = ClaimOrderCoordinator(web3: web3)
        claimOrderCoordinator?.claimOrder(
                signedOrder: signedOrder,
                expiry: signedOrder.order.expiry,
                v: v,
                r: r,
                s: s,
                contractAddress: signedOrder.order.contractAddress,
                recipient: wallet.address.eip55String
        ) { result in
            let strongSelf = self
            switch result {
            case .success(let payload):
                let address: Address = strongSelf.wallet.address
                let transaction = UnconfirmedTransaction(
                        transferType: .ERC875TokenOrder(tokenObject),
                        value: BigInt(signedOrder.order.price),
                        to: address,
                        data: Data(bytes: payload.hexa2Bytes),
                        gasLimit: GasLimitConfiguration.maxGasLimit,
                        tokenId: .none,
                        gasPrice: GasPriceConfiguration.defaultPrice,
                        nonce: .none,
                        v: v,
                        r: r,
                        s: s,
                        expiry: signedOrder.order.expiry,
                        indices: signedOrder.order.indices,
                        tokenIds: signedOrder.order.tokenIds
                )

                let session = strongSelf.walletSessions[server]
                let account = try! EtherKeystore().getAccount(for: wallet.address)!
                let configurator = TransactionConfigurator(
                        session: session,
                        account: account,
                        transaction: transaction
                )

                let signTransaction = configurator.formUnsignedTransaction()

                //TODO why is the gas price loaded in twice?
                let signedTransaction = UnsignedTransaction(
                        value: signTransaction.value,
                        account: account,
                        to: signTransaction.to,
                        nonce: signTransaction.nonce,
                        data: signTransaction.data,
                        gasPrice: GasPriceConfiguration.defaultPrice,
                        gasLimit: signTransaction.gasLimit,
                        server: server
                )
                let sendTransactionCoordinator = SendTransactionCoordinator(
                        session: session,
                        keystore: strongSelf.keystore,
                        confirmType: .signThenSend
                )

                sendTransactionCoordinator.send(transaction: signedTransaction) { result in
                    switch result {
                    case .success(let res):
                        completion(true)
                        print(res)
                    case .failure(let error):
                        completion(false)
                        print(error)
                    }
                }
            case .failure: break
            }
        }
    }

    func addImported(contract: String, forServer server: RPCServer) {
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
}

extension InCoordinator: CanOpenURL {
    private func open(url: URL, in viewController: UIViewController) {
        guard let account = keystore.recentlyUsedWallet else { return }

        //TODO duplication of code to set up a BrowserCoordinator when creating the application's tabbar
        let realm = self.realm(forAccount: keystore.recentlyUsedWallet!)
        let browserCoordinator = createBrowserCoordinator(sessions: walletSessions, realm: realm, browserOnly: true)
        let controller = browserCoordinator.navigationController
        browserCoordinator.open(url: url, animated: false)
        viewController.present(controller, animated: true, completion: nil)
    }

    func didPressViewContractWebPage(forContract contract: String, server: RPCServer, in viewController: UIViewController) {
        let url = server.etherscanContractDetailsWebPageURL(for: contract)
        open(url: url, in: viewController)
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

    func delete(account: Wallet, in coordinator: SettingsCoordinator) {
        let realm = self.realm(forAccount: account)
        for each in RPCServer.allCases {
            let transactionsStorage = TransactionsStorage(realm: realm, server: each)
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
}

extension InCoordinator: PaymentCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator) {
        switch result {
        case .sentTransaction(let transaction):
            handlePendingTransaction(transaction: transaction)
            coordinator.navigationController.dismiss(animated: true, completion: nil)
            showTransactionSent(transaction: transaction)
            removeCoordinator(coordinator)

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

extension InCoordinator: PromptBackupCoordinatorDelegate {
    func viewControllerForPresenting(in coordinator: PromptBackupCoordinator) -> UIViewController? {
        return navigationController
    }

    func didFinish(in coordinator: PromptBackupCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension InCoordinator: DappBrowserCoordinatorDelegate{
    func didSentTransaction(transaction: SentTransaction, inCoordinator coordinator: DappBrowserCoordinator) {
        handlePendingTransaction(transaction: transaction)
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
