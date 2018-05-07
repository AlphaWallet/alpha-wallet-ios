// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit
import RealmSwift
import BigInt

protocol InCoordinatorDelegate: class {
    func didCancel(in coordinator: InCoordinator)
    func didUpdateAccounts(in coordinator: InCoordinator)
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
    var config: Config
    let appTracker: AppTracker
    lazy var ethPrice: Subscribable<Double> = {
        var value = Subscribable<Double>(nil)
        fetchEthPrice()
        return value
    }()
    var ethBalance = Subscribable<BigInt>(nil)
    weak var delegate: InCoordinatorDelegate?
    var transactionCoordinator: TransactionCoordinator? {
        return self.coordinators.flatMap {
            $0 as? TransactionCoordinator
        }.first
    }

    var ticketsCoordinator: TicketsCoordinator? {
        return self.coordinators.flatMap {
            $0 as? TicketsCoordinator
        }.first
    }

    var tabBarController: UITabBarController? {
        return self.navigationController.viewControllers.first as? UITabBarController
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
            config: Config = Config(),
            appTracker: AppTracker = AppTracker()
    ) {
        self.navigationController = navigationController
        self.initialWallet = wallet
        self.keystore = keystore
        self.config = config
        self.appTracker = appTracker
    }

    func start() {
        showTabBar(for: initialWallet)
        checkDevice()

        helpUsCoordinator.start()
        addCoordinator(helpUsCoordinator)
    }

    func fetchEthPrice() {
        let keystore = try! EtherKeystore()
        let migration = MigrationInitializer(account: keystore.recentlyUsedWallet! , chainID: config.chainID)
        migration.perform()
        let web3 = self.web3(for: config.server)
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: keystore.recentlyUsedWallet!, config: config, web3: web3)
        tokensStorage.updatePrices()

        let etherToken = TokensDataStore.etherToken(for: config)
        tokensStorage.tokensModel.subscribe {[weak self] tokensModel in
            guard let tokens = tokensModel, let eth = tokens.first(where: { $0 == etherToken }) else {
                return
            }
            var ticker = tokensStorage.coinTicker(for: eth)
            if let ticker = ticker {
                self?.ethPrice.value = Double(ticker.price)
            } else {
                tokensStorage.updatePricesAfterComingOnline()
            }
        }
    }

    func showTabBar(for account: Wallet) {

        let migration = MigrationInitializer(account: account, chainID: config.chainID)
        migration.perform()

        let web3 = self.web3(for: config.server)
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: account, config: config, web3: web3)
        let alphaWalletTokensStorage = TokensDataStore(realm: realm, account: account, config: config, web3: web3)
        let balanceCoordinator = GetBalanceCoordinator(web3: web3)
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

        let marketplaceController = MarketplaceViewController()
        let marketplaceNavigationController = UINavigationController(rootViewController: marketplaceController)
        marketplaceController.tabBarItem = UITabBarItem(title: R.string.localizable.aMarketplaceTabbarItemTitle(), image: R.image.tab_marketplace()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.tab_marketplace())

        let tabBarController = TabBarController()
        tabBarController.viewControllers = [
            marketplaceNavigationController,
        ]
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
                    tokensStorage: alphaWalletTokensStorage
            )
            tokensCoordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet()?.withRenderingMode(.alwaysOriginal), selectedImage: R.image.tab_wallet())
            tokensCoordinator.delegate = self
            tokensCoordinator.start()
            addCoordinator(tokensCoordinator)
            tabBarController.viewControllers?.append(tokensCoordinator.navigationController)
        }
        tabBarController.viewControllers?.append(transactionCoordinator.navigationController)

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

        keystore.recentlyUsedWallet = account

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
                self?.promptBackupWallet()
            }
        }
    }

    private func promptBackupWallet() {
        let coordinator = PromptBackupCoordinator()
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
        self.navigationController.dismiss(animated: false, completion: nil)
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        coordinator.stop()
        removeAllCoordinators()
        showTabBar(for: account)
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
                    storage: tokenStorage
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

    func showPaymentFlow(for paymentFlow: PaymentFlow, ticketHolders: [TicketHolder] = [], in ticketsCoordinator: TicketsCoordinator) {
        guard let transactionCoordinator = transactionCoordinator else {
            return
        }
        //TODO do we need to pass these (especially tokenStorage) to showTransferViewController(for:ticketHolders:) to make sure storage is synchronized?
        let session = transactionCoordinator.session
        let tokenStorage = transactionCoordinator.tokensStorage

        switch (paymentFlow, session.account.type) {
        case (.send, .real), (.request, _):
            ticketsCoordinator.showTransferViewController(for: paymentFlow, ticketHolders: ticketHolders)
        case (_, _):
            navigationController.displayError(error: InCoordinatorError.onlyWatchAccount)
        }
    }

    func showTicketList(for type: PaymentFlow, token: TokenObject) {
        guard let transactionCoordinator = transactionCoordinator else {
            return
        }

        let session = transactionCoordinator.session
        let tokenStorage = transactionCoordinator.tokensStorage

        let ticketsCoordinator = TicketsCoordinator(
            session: session,
            keystore: keystore,
            tokensStorage: tokenStorage,
            ethPrice: ethPrice
        )
        addCoordinator(ticketsCoordinator)
        ticketsCoordinator.token = token
        ticketsCoordinator.type = type
        ticketsCoordinator.delegate = self
        ticketsCoordinator.start()
        navigationController.present(ticketsCoordinator.navigationController, animated: true, completion: nil)
    }

    func showTicketListToRedeem(for token: TokenObject, coordinator: TicketsCoordinator) {
        coordinator.showRedeemViewController()
    }

    func showTicketListToSell(for paymentFlow: PaymentFlow, coordinator: TicketsCoordinator) {
        coordinator.showSellViewController(for: paymentFlow)
    }

    private func handlePendingTransaction(transaction: SentTransaction) {
        transactionCoordinator?.dataCoordinator.addSentTransaction(transaction)
    }

    private func realm(for config: Realm.Configuration) -> Realm {
        return try! Realm(configuration: config)
    }

    private func web3(for server: RPCServer) -> Web3Swift {
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
}

extension InCoordinator: TicketsCoordinatorDelegate {

    func didPressTransfer(for type: PaymentFlow, ticketHolders: [TicketHolder], in coordinator: TicketsCoordinator) {
        showPaymentFlow(for: type, ticketHolders: ticketHolders, in: coordinator)
    }

    func didPressRedeem(for token: TokenObject, in coordinator: TicketsCoordinator) {
        showTicketListToRedeem(for: token, coordinator: coordinator)
    }

    func didPressSell(for type: PaymentFlow, in coordinator: TicketsCoordinator) {
        showTicketListToSell(for: type, coordinator: coordinator)
    }

    func didCancel(in coordinator: TicketsCoordinator) {
        navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didPressViewRedemptionInfo(in viewController: UIViewController) {
        let controller = TicketRedemptionInfoViewController()
		viewController.navigationController?.pushViewController(controller, animated: true)
    }

    func didPressViewEthereumInfo(in viewController: UIViewController) {
        let controller = WhatIsEthereumInfoViewController()
        viewController.navigationController?.pushViewController(controller, animated: true)
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
    }
}

extension InCoordinator: TokensCoordinatorDelegate {
    
    func didPress(for type: PaymentFlow, in coordinator: TokensCoordinator) {
        showPaymentFlow(for: type)
    }

    func didPressStormBird(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator) {
        showTicketList(for: type, token: token)
    }

    // When a user clicks a Universal Link, either the user pays to publish a
    // transaction or, if the ticket price = 0 (new purchase or incoming
    // transfer from a buddy), the user can send the data to a paymaster.
    // This function deal with the special case that the ticket price = 0
    // but not sent to the paymaster because the user has ether.

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void) {
        let web3 = self.web3(for: config.server)
        web3.start()
        let signature = signedOrder.signature.substring(from: 2)
        let v = UInt8(signature.substring(from: 128), radix: 16)!
        let r = "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64)))
        let s = "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))

        ClaimOrderCoordinator(web3: web3).claimOrder(indices: signedOrder.order.indices, expiry: signedOrder.order.expiry, v: v, r: r, s: s) {
            result in
            switch result {
            case .success(let payload):
                let address: Address = self.initialWallet.address
                let transaction = UnconfirmedTransaction(
                        transferType: .stormBirdOrder(tokenObject),
                        value: BigInt(signedOrder.order.price),
                        to: address,
                        data: Data(bytes: payload.hexa2Bytes),
                        gasLimit: Constants.gasLimit,
                        gasPrice: Constants.gasPriceDefaultStormbird,
                        nonce: .none,
                        v: v,
                        r: r,
                        s: s,
                        expiry: signedOrder.order.expiry,
                        indices: signedOrder.order.indices
                )

                let wallet = self.keystore.recentlyUsedWallet!
                let migration = MigrationInitializer(account: wallet, chainID: self.config.chainID)
                migration.perform()
                let realm = self.realm(for: migration.config)
                let tokensStorage = TokensDataStore(realm: realm, account: wallet, config: self.config, web3: web3)
                let balance = BalanceCoordinator(wallet: wallet, config: self.config, storage: tokensStorage)
                let session = WalletSession(
                        account: wallet,
                        config: self.config,
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
                        gasPrice: Constants.gasPriceDefaultStormbird,
                        gasLimit: signTransaction.gasLimit,
                        chainID: self.config.chainID
                )
                let sendTransactionCoordinator = SendTransactionCoordinator(
                        session: session,
                        keystore: self.keystore,
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
