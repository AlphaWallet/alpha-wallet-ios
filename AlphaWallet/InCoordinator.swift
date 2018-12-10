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

class InCoordinator: Coordinator {
    private let initialWallet: Wallet
    private let config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    private let appTracker: AppTracker
    private var callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator? {
        didSet {
            XMLHandler.callForAssetAttributeCoordinator = callForAssetAttributeCoordinator
        }
    }
    private var transactionCoordinator: TransactionCoordinator? {
        return coordinators.compactMap {
            $0 as? TransactionCoordinator
        }.first
    }
    private var transactionCoordinators: [TransactionCoordinator] {
        return coordinators.compactMap { $0 as? TransactionCoordinator }
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
    lazy var ethPrice: Subscribable<Double> = {
        var value = Subscribable<Double>(nil)
        fetchEthPrice()
        return value
    }()
    var ethBalance = Subscribable<BigInt>(nil)
    weak var delegate: InCoordinatorDelegate?
    var tabBarController: UITabBarController? {
        return navigationController.viewControllers.first as? UITabBarController
    }

    init(
            navigationController: UINavigationController = NavigationController(),
            wallet: Wallet,
            keystore: Keystore,
            assetDefinitionStore: AssetDefinitionStore,
            config: Config = Config(),
            appTracker: AppTracker = AppTracker()
    ) {
        self.navigationController = navigationController
        self.initialWallet = wallet
        self.keystore = keystore
        self.config = config
        self.appTracker = appTracker
        self.assetDefinitionStore = assetDefinitionStore
        self.assetDefinitionStore.enableFetchXMLForContractInPasteboard()
    }

    func start() {
        showTabBar(for: initialWallet)
        checkDevice()

        helpUsCoordinator.start()
        addCoordinator(helpUsCoordinator)
        fetchXMLAssetDefinitions()
    }

    //TODO use more of this in InCoordinator (watch out for which wallet we are creating it for)
    func createTokensDatastore() -> TokensDataStore? {
        guard let wallet = keystore.recentlyUsedWallet else { return nil }
        let migration = MigrationInitializer(account: wallet, chainID: config.chainID)
        migration.perform()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: wallet, config: config, assetDefinitionStore: assetDefinitionStore)
        return tokensStorage
    }

    private func fetchEthPrice() {
        let migration = MigrationInitializer(account: keystore.recentlyUsedWallet!, chainID: config.chainID)
        migration.perform()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: keystore.recentlyUsedWallet!, config: config, assetDefinitionStore: assetDefinitionStore)
        tokensStorage.updatePrices()

        let etherToken = TokensDataStore.etherToken(for: config)
        tokensStorage.tokensModel.subscribe {[weak self] tokensModel in
            guard let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else {
                return
            }
            if let ticker = tokensStorage.coinTicker(for: eth) {
                self?.ethPrice.value = Double(ticker.price_usd)
            } else {
                tokensStorage.updatePricesAfterComingOnline()
            }
        }
    }

    func showTabBar(for account: Wallet) {
        let migration = MigrationInitializer(account: account, chainID: config.chainID)
        migration.perform()
        //Debugging
        print(migration.config.fileURL!)

        //TODO this is bad because it is optional and effectively a global
        if let tokensDataStore = createTokensDatastore() {
            callForAssetAttributeCoordinator = CallForAssetAttributeCoordinator(config: config, tokensDataStore: tokensDataStore)
        }

        //TODO creating many objects here. Messy. Improve?
        let web3 = self.web3()
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: account, config: config, assetDefinitionStore: assetDefinitionStore)
        let alphaWalletTokensStorage = TokensDataStore(realm: realm, account: account, config: config, assetDefinitionStore: assetDefinitionStore)
        let balance = BalanceCoordinator(wallet: account, config: config, storage: tokensStorage)
        let session = WalletSession(
                account: account,
                config: config,
                web3: web3,
                balanceCoordinator: balance
        )
        let transactionsStorage = TransactionsStorage(realm: realm)
        transactionsStorage.removeTransactions(for: [.failed, .pending, .unknown])
        keystore.recentlyUsedWallet = account

        let tabBarController = createTabBarController(session: session, keystore: keystore, alphaWalletTokensStorage: alphaWalletTokensStorage, tokensDataStore: tokensStorage, transactionsStorage: transactionsStorage, realm: realm)

        navigationController.setViewControllers(
                [tabBarController],
                animated: false
        )
        navigationController.setNavigationBarHidden(true, animated: false)

        let inCoordinatorViewModel = InCoordinatorViewModel(config: config)
        showTab(inCoordinatorViewModel.initialTab)

        let etherToken = TokensDataStore.etherToken(for: config)
        tokensStorage.tokensModel.subscribe {[weak self] tokensModel in
            guard let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else {
                return
            }
            if let balance = BigInt(eth.value) {
                self?.ethBalance.value = BigInt(eth.value)
                guard !(balance.isZero) else { return }
                self?.promptBackupWallet(withAddress: account.address.description)
            }
        }
    }

    private func createTokensCoordinator(session: WalletSession, tokensDataStore: TokensDataStore) -> TokensCoordinator {
        let coordinator = TokensCoordinator(
                session: session,
                keystore: keystore,
                tokensStorage: tokensDataStore,
                ethPrice: ethPrice,
                assetDefinitionStore: assetDefinitionStore
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.tab_wallet())
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createTransactionCoordinator(session: WalletSession, transactionsStorage: TransactionsStorage, keystore: Keystore, tokensDataStore: TokensDataStore) -> TransactionCoordinator {
        let coordinator = TransactionCoordinator(
                session: session,
                storage: transactionsStorage,
                keystore: keystore,
                tokensStorage: tokensDataStore
        )
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.transactionsTabbarItemTitle(), image: R.image.feed()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.feed())
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        return coordinator
    }

    private func createBrowserCoordinator(session: WalletSession, keystore: Keystore, realm: Realm) -> DappBrowserCoordinator {
        let coordinator = DappBrowserCoordinator(session: session, keystore: keystore, sharedRealm: realm)
        coordinator.delegate = self
        coordinator.start()
        coordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.browserTabbarItemTitle(), image: R.image.dapps_icon(), selectedImage: nil)
        addCoordinator(coordinator)
        return coordinator
    }

    private func createSettingsCoordinator(session: WalletSession, keystore: Keystore, transactionsStorage: TransactionsStorage) -> SettingsCoordinator {
        let balanceCoordinator = GetBalanceCoordinator(config: config)
        let coordinator = SettingsCoordinator(
                keystore: keystore,
                session: session,
                storage: transactionsStorage,
                balanceCoordinator: balanceCoordinator
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
    private func createTabBarController(session: WalletSession, keystore: Keystore, alphaWalletTokensStorage: TokensDataStore, tokensDataStore: TokensDataStore, transactionsStorage: TransactionsStorage, realm: Realm) -> UITabBarController {
        var viewControllers = [UIViewController]()

        let inCoordinatorViewModel = InCoordinatorViewModel(config: config)
        if inCoordinatorViewModel.tokensAvailable {
            let tokensCoordinator = createTokensCoordinator(session: session, tokensDataStore: alphaWalletTokensStorage)
            viewControllers.append(tokensCoordinator.navigationController)
        }

        let transactionCoordinator = createTransactionCoordinator(
                session: session,
                transactionsStorage: transactionsStorage,
                keystore: keystore,
                tokensDataStore: tokensDataStore
        )
        viewControllers.append(transactionCoordinator.navigationController)

        let browserCoordinator = createBrowserCoordinator(session: session, keystore: keystore, realm: realm)
        viewControllers.append(browserCoordinator.navigationController)

        let settingsCoordinator = createSettingsCoordinator(
                session: session,
                keystore: keystore,
                transactionsStorage: transactionsStorage
        )
        viewControllers.append(settingsCoordinator.navigationController)

        let tabBarController = TabBarController()
        tabBarController.tabBar.isTranslucent = false
        tabBarController.viewControllers = viewControllers
        hideTitlesInTabBarController(tabBarController: tabBarController)
        return tabBarController
    }

    private func promptBackupWallet(withAddress address: String) {
        let coordinator = PromptBackupCoordinator(walletAddress: address)
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
        callForAssetAttributeCoordinator = nil
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

    func showPaymentFlow(for type: PaymentFlow) {
        guard let transactionCoordinator = transactionCoordinator else {
            return
        }
        let session = transactionCoordinator.session
        let tokenStorage = transactionCoordinator.tokensStorage

        switch (type, session.account.type) {
        case (.send, .real), (.request, _):
            let coordinator = PaymentCoordinator(
                    flow: type,
                    session: session,
                    keystore: keystore,
                    storage: tokenStorage,
                    ethPrice: ethPrice
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
            navigationController.displayError(error: InCoordinatorError.onlyWatchAccount)
        }
    }

    private func handlePendingTransaction(transaction: SentTransaction) {
        transactionCoordinator?.dataCoordinator.addSentTransaction(transaction)
    }

    private func realm(for config: Realm.Configuration) -> Realm {
        return try! Realm(configuration: config)
    }

    private func web3() -> Web3Swift {
        return Web3Swift(url: config.rpcURL)
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
        let migration = MigrationInitializer(account: keystore.recentlyUsedWallet!, chainID: config.chainID)
        migration.perform()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: keystore.recentlyUsedWallet!, config: config, assetDefinitionStore: assetDefinitionStore)

        let coordinator = FetchAssetDefinitionsCoordinator(assetDefinitionStore: assetDefinitionStore, tokensDataStore: tokensStorage)
        coordinator.start()
        addCoordinator(coordinator)
    }

    // When a user clicks a Universal Link, either the user pays to publish a
    // transaction or, if the token price = 0 (new purchase or incoming
    // transfer from a buddy), the user can send the data to a paymaster.
    // This function deal with the special case that the token price = 0
    // but not sent to the paymaster because the user has ether.
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void) {
        let web3 = self.web3()
        web3.start()
        let signature = signedOrder.signature.substring(from: 2)
        let v = UInt8(signature.substring(from: 128), radix: 16)!
        let r = "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64)))
        let s = "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
        guard let wallet = keystore.recentlyUsedWallet else { return }

        ClaimOrderCoordinator(web3: web3).claimOrder(
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
                let address: Address = strongSelf.initialWallet.address
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

                let wallet = strongSelf.keystore.recentlyUsedWallet!
                let migration = MigrationInitializer(
                        account: wallet,
                        chainID: strongSelf.config.chainID
                )
                migration.perform()
                let realm = strongSelf.realm(for: migration.config)

                let tokensStorage = TokensDataStore(
                        realm: realm,
                        account: wallet,
                        config: strongSelf.config,
                        assetDefinitionStore: strongSelf.assetDefinitionStore
                )

                let balance = BalanceCoordinator(
                        wallet: wallet,
                        config: strongSelf.config,
                        storage: tokensStorage
                )
                let session = WalletSession(
                        account: wallet,
                        config: strongSelf.config,
                        web3: web3,
                        balanceCoordinator: balance
                )

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
                        chainID: strongSelf.config.chainID
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

    func addImported(contract: String) {
        let tokensCoordinator = coordinators.first { $0 is TokensCoordinator } as? TokensCoordinator
        tokensCoordinator?.addImportedToken(for: contract)
    }
}

extension InCoordinator: CanOpenURL {
    private func open(url: URL, in viewController: UIViewController) {
        guard let account = keystore.recentlyUsedWallet else { return }

        //TODO duplication of code to set up a BrowserCoordinator when creating the application's tabbar
        let migration = MigrationInitializer(account: keystore.recentlyUsedWallet!, chainID: config.chainID)
        migration.perform()
        let web3 = self.web3()
        web3.start()
        let realm = self.realm(for: migration.config)

        let tokensStorage = TokensDataStore(realm: realm, account: account, config: config, assetDefinitionStore: assetDefinitionStore)

        let balance = BalanceCoordinator(wallet: account, config: config, storage: tokensStorage)
        let session = WalletSession(
                account: account,
                config: config,
                web3: web3,
                balanceCoordinator: balance
        )

        let browserCoordinator = DappBrowserCoordinator(session: session, keystore: keystore, sharedRealm: realm)
        browserCoordinator.delegate = self
        browserCoordinator.start()
        addCoordinator(browserCoordinator)

        let controller = browserCoordinator.navigationController
        browserCoordinator.open(url: url, browserOnly: true, animated: false)
        viewController.present(controller, animated: true, completion: nil)
    }

    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        let url = config.server.etherscanContractDetailsWebPageURL(for: contract)
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
    func didPress(for type: PaymentFlow, in coordinator: TransactionCoordinator) {
        showPaymentFlow(for: type)
    }
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
        showPaymentFlow(for: .request)
        delegate?.didShowWallet(in: self)
    }

    func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController? {
        return delegate?.assetDefinitionsOverrideViewController(for: self)
    }
}

extension InCoordinator: TokensCoordinatorDelegate {
    func didPress(for type: PaymentFlow, in coordinator: TokensCoordinator) {
        showPaymentFlow(for: type)
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
