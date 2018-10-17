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

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    let initialWallet: Wallet
    var keystore: Keystore
    private var config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    let appTracker: AppTracker
    lazy var ethPrice: Subscribable<Double> = {
        var value = Subscribable<Double>(nil)
        fetchEthPrice()
        return value
    }()
    var ethBalance = Subscribable<BigInt>(nil)
    weak var delegate: InCoordinatorDelegate?
    var transactionCoordinator: TransactionCoordinator? {
        return coordinators.compactMap {
            $0 as? TransactionCoordinator
        }.first
    }
    private var transactionCoordinators: [TransactionCoordinator] {
        return coordinators.compactMap { $0 as? TransactionCoordinator }
    }

    var tabBarController: UITabBarController? {
        return navigationController.viewControllers.first as? UITabBarController
    }

    lazy var helpUsCoordinator: HelpUsCoordinator = {
        return HelpUsCoordinator(
                navigationController: navigationController,
                appTracker: appTracker
        )
    }()

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
        let web3 = self.web3()
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: wallet, config: config, web3: web3, assetDefinitionStore: assetDefinitionStore)
        return tokensStorage
    }

    func fetchEthPrice() {
        let migration = MigrationInitializer(account: keystore.recentlyUsedWallet!, chainID: config.chainID)
        migration.perform()
        let web3 = self.web3()
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: keystore.recentlyUsedWallet!, config: config, web3: web3, assetDefinitionStore: assetDefinitionStore)
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

        let web3 = self.web3()
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: account, config: config, web3: web3, assetDefinitionStore: assetDefinitionStore)
        let alphaWalletTokensStorage = TokensDataStore(realm: realm, account: account, config: config, web3: web3, assetDefinitionStore: assetDefinitionStore)
        let balanceCoordinator = GetBalanceCoordinator(config: config)
        let balance = BalanceCoordinator(wallet: account, config: config, storage: tokensStorage)
        let session = WalletSession(
                account: account,
                config: config,
                web3: web3,
                balanceCoordinator: balance
        )
        let transactionsStorage = TransactionsStorage(
                realm: realm
        )
        transactionsStorage.removeTransactions(for: [.failed, .pending, .unknown])
        keystore.recentlyUsedWallet = account

        let inCoordinatorViewModel = InCoordinatorViewModel(config: config)
        let transactionCoordinator = TransactionCoordinator(
                session: session,
                storage: transactionsStorage,
                keystore: keystore,
                tokensStorage: tokensStorage
        )
        transactionCoordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.transactionsTabbarItemTitle(), image: R.image.feed()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.feed())
        transactionCoordinator.delegate = self
        transactionCoordinator.start()
        addCoordinator(transactionCoordinator)

        let tabBarController = TabBarController()
        tabBarController.tabBar.isTranslucent = false
        tabBarController.didShake = { [weak self] in
            if inCoordinatorViewModel.canActivateDebugMode {
                self?.activateDebug()
            }
        }

        if inCoordinatorViewModel.tokensAvailable {
            let tokensCoordinator = TokensCoordinator(
                    session: session,
                    keystore: keystore,
                    tokensStorage: alphaWalletTokensStorage,
                    assetDefinitionStore: assetDefinitionStore
            )
            tokensCoordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.tab_wallet())
            tokensCoordinator.delegate = self
            tokensCoordinator.start()
            addCoordinator(tokensCoordinator)
            tabBarController.viewControllers = [
                tokensCoordinator.navigationController
            ]
        }

        if let viewControllers = tabBarController.viewControllers, !viewControllers.isEmpty {
            tabBarController.viewControllers?.append(transactionCoordinator.navigationController)
        } else {
            tabBarController.viewControllers = [transactionCoordinator.navigationController]
        }


        let browserCoordinator = BrowserCoordinator(session: session, keystore: keystore, sharedRealm: realm)
        browserCoordinator.delegate = self
        browserCoordinator.start()
        browserCoordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.browserTabbarItemTitle(), image: R.image.dapps_icon(), selectedImage: nil)

        addCoordinator(browserCoordinator)
        if let viewControllers = tabBarController.viewControllers, !viewControllers.isEmpty {
            tabBarController.viewControllers?.append(browserCoordinator.navigationController)
        } else {
            tabBarController.viewControllers = [browserCoordinator.navigationController]
        }

        let alphaSettingsCoordinator = SettingsCoordinator(
                keystore: keystore,
                session: session,
                storage: transactionsStorage,
                balanceCoordinator: balanceCoordinator
        )
        alphaSettingsCoordinator.rootViewController.tabBarItem = UITabBarItem(
                title: R.string.localizable.aSettingsNavigationTitle(),
                image: R.image.tab_settings()?.withRenderingMode(.alwaysOriginal),
                selectedImage: R.image.tab_settings()
        )
        alphaSettingsCoordinator.delegate = self
        alphaSettingsCoordinator.start()
        addCoordinator(alphaSettingsCoordinator)
        if let viewControllers = tabBarController.viewControllers, !viewControllers.isEmpty {
            tabBarController.viewControllers?.append(alphaSettingsCoordinator.navigationController)
        } else {
            tabBarController.viewControllers = [alphaSettingsCoordinator.navigationController]
        }

        navigationController.setViewControllers(
                [tabBarController],
                animated: false
        )
        navigationController.setNavigationBarHidden(true, animated: false)
        addCoordinator(transactionCoordinator)

		hideTitlesInTabBarController(tabBarController: tabBarController)

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

    @objc func dismissTransactions() {
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

    @objc func activateDebug() {
        config.isDebugEnabled = !config.isDebugEnabled

        guard let transactionCoordinator = transactionCoordinator else {
            return
        }
        restart(for: transactionCoordinator.session.account, in: transactionCoordinator)
    }

    func restart(for account: Wallet, in coordinator: TransactionCoordinator) {
        navigationController.dismiss(animated: false, completion: nil)
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        coordinator.stop()
        removeAllCoordinators()
        OpenSea.sharedInstance.reset()
        showTabBar(for: account)
        fetchXMLAssetDefinitions()
    }

    func removeAllCoordinators() {
        coordinators.removeAll()
    }

    func checkDevice() {
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

    func showPaymentFlow(for paymentFlow: PaymentFlow, tokenHolders: [TokenHolder] = [], in tokensCardCoordinator: TokensCardCoordinator) {
        guard let transactionCoordinator = transactionCoordinator else {
            return
        }
        //TODO do we need to pass these (especially tokenStorage) to showTransferViewController(for:tokenHolders:) to make sure storage is synchronized?
        let session = transactionCoordinator.session

        switch (paymentFlow, session.account.type) {
        case (.send, .real), (.request, _):
            tokensCardCoordinator.showTransferViewController(for: paymentFlow, tokenHolders: tokenHolders)
        case (_, _):
            tokensCardCoordinator.navigationController.displayError(error: InCoordinatorError.onlyWatchAccount)
        }
    }

    func showTokenList(for type: PaymentFlow, token: TokenObject) {
        guard let transactionCoordinator = transactionCoordinator else {
            return
        }

        guard !token.nonZeroBalance.isEmpty else {
            navigationController.displayError(error: NoTokenError())
            return
        }

        let session = transactionCoordinator.session
        let tokenStorage = transactionCoordinator.tokensStorage

        let tokensCardCoordinator = TokensCardCoordinator(
            session: session,
            keystore: keystore,
            tokensStorage: tokenStorage,
            ethPrice: ethPrice,
            token: token,
            assetDefinitionStore: assetDefinitionStore
        )
        addCoordinator(tokensCardCoordinator)
        tokensCardCoordinator.delegate = self
        tokensCardCoordinator.start()
        switch (type, session.account.type) {
        case (.send, .real), (.request, _):
            makeCoordinatorReadOnlyIfNotSupportedByOpenSeaERC721(coordinator: tokensCardCoordinator, token: token)
            navigationController.present(tokensCardCoordinator.navigationController, animated: true, completion: nil)
        case (.send, .watch), (.request, _):
            tokensCardCoordinator.isReadOnly = true
            navigationController.present(tokensCardCoordinator.navigationController, animated: true, completion: nil)
        case (_, _):
            navigationController.displayError(error: InCoordinatorError.onlyWatchAccount)
        }
    }

    func showTokenListToRedeem(for token: TokenObject, coordinator: TokensCardCoordinator) {
        coordinator.showRedeemViewController()
    }

    func showTokenListToSell(for paymentFlow: PaymentFlow, coordinator: TokensCardCoordinator) {
        coordinator.showSellViewController(for: paymentFlow)
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
        let alertController = UIAlertController(title: R.string.localizable.sendActionTransactionSent(), message: R.string.localizable.sendActionTransactionSentWait(), preferredStyle: UIAlertControllerStyle.alert)
        let copyAction = UIAlertAction(title: R.string.localizable.sendActionCopyTransactionTitle(), style: UIAlertActionStyle.default, handler: { _ in
            UIPasteboard.general.string = transaction.id
        })
        alertController.addAction(copyAction)
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: UIAlertActionStyle.default, handler: nil))
        navigationController.present(alertController, animated: true, completion: nil)
    }

    private func fetchXMLAssetDefinitions() {
        let migration = MigrationInitializer(account: keystore.recentlyUsedWallet!, chainID: config.chainID)
        migration.perform()
        let web3 = self.web3()
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: keystore.recentlyUsedWallet!, config: config, web3: web3, assetDefinitionStore: assetDefinitionStore)

        let coordinator = FetchAssetDefinitionsCoordinator(assetDefinitionStore: assetDefinitionStore, tokensDataStore: tokensStorage)
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func makeCoordinatorReadOnlyIfNotSupportedByOpenSeaERC721(coordinator: TokensCardCoordinator, token: TokenObject) {
        switch token.type {
        case .ether, .erc20, .erc875:
            break
        case .erc721:
            switch OpenSeaNonFungibleTokenHandling(token: token) {
            case .supportedByOpenSea:
                break
            case .notSupportedByOpenSea:
                coordinator.isReadOnly = true
            }
        }
    }
}

extension InCoordinator: TokensCardCoordinatorDelegate {

    func didPressTransfer(for type: PaymentFlow, tokenHolders: [TokenHolder], in coordinator: TokensCardCoordinator) {
        showPaymentFlow(for: type, tokenHolders: tokenHolders, in: coordinator)
    }

    func didPressRedeem(for token: TokenObject, in coordinator: TokensCardCoordinator) {
        showTokenListToRedeem(for: token, coordinator: coordinator)
    }

    func didPressSell(for type: PaymentFlow, in coordinator: TokensCardCoordinator) {
        showTokenListToSell(for: type, coordinator: coordinator)
    }

    func didCancel(in coordinator: TokensCardCoordinator) {
        navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didPressViewRedemptionInfo(in viewController: UIViewController) {
        let controller = TokenCardRedemptionInfoViewController(delegate: self)
		viewController.navigationController?.pushViewController(controller, animated: true)
    }

    func didPressViewEthereumInfo(in viewController: UIViewController) {
        let controller = WhatIsEthereumInfoViewController(delegate: self)
        viewController.navigationController?.pushViewController(controller, animated: true)
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

        let tokensStorage = TokensDataStore(realm: realm, account: account, config: config, web3: web3, assetDefinitionStore: assetDefinitionStore)

        let balance = BalanceCoordinator(wallet: account, config: config, storage: tokensStorage)
        let session = WalletSession(
                account: account,
                config: config,
                web3: web3,
                balanceCoordinator: balance
        )

        let browserCoordinator = BrowserCoordinator(session: session, keystore: keystore, sharedRealm: realm)
        browserCoordinator.delegate = self
        browserCoordinator.start()
        addCoordinator(browserCoordinator)

        let controller = browserCoordinator.navigationController
        browserCoordinator.openURL(url)
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

    func didCancel(in coordinator: TransactionCoordinator) {
        delegate?.didCancel(in: self)
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        coordinator.stop()
        removeAllCoordinators()
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

    func didPressERC721(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator) {
        showTokenList(for: type, token: token)
    }

    func didPressERC875(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator) {
        showTokenList(for: type, token: token)
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

        ClaimOrderCoordinator(web3: web3).claimOrder(
                signedOrder: signedOrder,
                expiry: signedOrder.order.expiry,
                v: v,
                r: r,
                s: s) { result in
            let strongSelf = self //else { return }
            switch result {
            case .success(let payload):
                let address: Address = strongSelf.initialWallet.address
                let transaction = UnconfirmedTransaction(
                        transferType: .ERC875TokenOrder(tokenObject),
                        value: BigInt(signedOrder.order.price),
                        to: address,
                        data: Data(bytes: payload.hexa2Bytes),
                        gasLimit: Constants.gasLimit,
                        tokenId: .none,
                        gasPrice: Constants.gasPriceDefaultERC875,
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
                    web3: web3,
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
                        gasPrice: Constants.gasPriceDefaultERC875,
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

extension InCoordinator: BrowserCoordinatorDelegate {
    func didSentTransaction(transaction: SentTransaction, in coordinator: BrowserCoordinator) {
        handlePendingTransaction(transaction: transaction)
    }

    func didPressCloseButton(in coordinator: BrowserCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }
}

struct NoTokenError: LocalizedError {
    var errorDescription: String? {
        return R.string.localizable.aWalletNoTokens()
    }
}

extension InCoordinator: StaticHTMLViewControllerDelegate {
}
