// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit
import RealmSwift

protocol InCoordinatorDelegate: class {
    func didCancel(in coordinator: InCoordinator)
    func didUpdateAccounts(in coordinator: InCoordinator)
}

enum Tabs {
    case transactions
    case tokens
    case settings
    case wallet
    case alphaWalletSettings

    var className: String {
        switch self {
        case .wallet:
            return String(describing: TokensViewController.self)
        case .tokens:
            return String(describing: TokensViewController.self)
        case .transactions:
            return String(describing: TransactionsViewController.self)
        case .settings:
            return String(describing: SettingsViewController.self)
        case .alphaWalletSettings:
            return String(describing: AlphaWalletSettingsViewController.self)
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

    func showTabBar(for account: Wallet) {

        let migration = MigrationInitializer(account: account, chainID: config.chainID)
        migration.perform()

        let web3 = self.web3(for: config.server)
        web3.start()
        let realm = self.realm(for: migration.config)
        let tokensStorage = TokensDataStore(realm: realm, account: account, config: config, web3: web3)
        let alphaWalletTokensStorage = AlphaWalletTokensDataStore(realm: realm, account: account, config: config, web3: web3)
        let balanceCoordinator = GetBalanceCoordinator(web3: web3)
        let balance = BalanceCoordinator(account: account, config: config, storage: tokensStorage)
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
        transactionCoordinator.rootViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("transactions.tabbar.item.title", value: "Transactions", comment: ""), image: R.image.feed(), selectedImage: nil)
        transactionCoordinator.delegate = self
        transactionCoordinator.start()
        addCoordinator(transactionCoordinator)

        let tabBarController = TabBarController()
        tabBarController.viewControllers = [
            transactionCoordinator.navigationController,
        ]
        tabBarController.tabBar.isTranslucent = false
        tabBarController.didShake = { [weak self] in
            if inCoordinatorViewModel.canActivateDebugMode {
                self?.activateDebug()
            }
        }

        if inCoordinatorViewModel.tokensAvailable {
            let tokenCoordinator = TokensCoordinator(
                    session: session,
                    keystore: keystore,
                    tokensStorage: tokensStorage
            )
            tokenCoordinator.rootViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("tokens.tabbar.item.title", value: "Tokens", comment: ""), image: R.image.coins(), selectedImage: nil)
            tokenCoordinator.delegate = self
            tokenCoordinator.start()
            addCoordinator(tokenCoordinator)
            tabBarController.viewControllers?.append(tokenCoordinator.navigationController)

            let alphaWalletTokensCoordinator = AlphaWalletTokensCoordinator(
                    session: session,
                    keystore: keystore,
                    tokensStorage: alphaWalletTokensStorage
            )
            alphaWalletTokensCoordinator.rootViewController.tabBarItem = UITabBarItem(title: R.string.localizable.walletTokensTabbarItemTitle(), image: R.image.tab_wallet(), selectedImage: nil)
            alphaWalletTokensCoordinator.delegate = self
            alphaWalletTokensCoordinator.start()
            addCoordinator(alphaWalletTokensCoordinator)
            tabBarController.viewControllers?.append(alphaWalletTokensCoordinator.navigationController)
        }

        let alphaWalletSettingsController = AlphaWalletSettingsViewController()
        alphaWalletSettingsController.delegate = self
        alphaWalletSettingsController.tabBarItem = UITabBarItem(title: R.string.localizable.aSettingsNavigationTitle(), image: R.image.tab_settings(), selectedImage: nil)
        tabBarController.viewControllers?.append(UINavigationController(rootViewController: alphaWalletSettingsController))

        let helpController = AlphaWalletHelpViewController()
        helpController.tabBarItem = UITabBarItem(title: R.string.localizable.aHelpNavigationTitle(), image: R.image.tab_help(), selectedImage: nil)
        tabBarController.viewControllers?.append(UINavigationController(rootViewController: helpController))

        let settingsCoordinator = SettingsCoordinator(
                keystore: keystore,
                session: session,
                storage: transactionsStorage,
                balanceCoordinator: balanceCoordinator
        )
        settingsCoordinator.rootViewController.tabBarItem = UITabBarItem(
                title: NSLocalizedString("settings.navigation.title", value: "Settings", comment: ""),
                image: R.image.settings_icon(),
                selectedImage: nil
        )
        settingsCoordinator.delegate = self
        settingsCoordinator.start()
        addCoordinator(settingsCoordinator)
        tabBarController.viewControllers?.append(settingsCoordinator.navigationController)

        navigationController.setViewControllers(
                [tabBarController],
                animated: false
        )
        navigationController.setNavigationBarHidden(true, animated: false)
        addCoordinator(transactionCoordinator)

        keystore.recentlyUsedWallet = account

        showTab(inCoordinatorViewModel.initialTab)
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
            navigationController.present(coordinator.navigationController, animated: true, completion: nil)
            coordinator.start()
            addCoordinator(coordinator)
        case (_, _):
            navigationController.displayError(error: InCoordinatorError.onlyWatchAccount)
        }
    }
    // TODO: Fix this
    func showPaymentFlow(for paymentFlow: PaymentFlow, ticketHolders: [TicketHolder] = [], in ticketsCoordinator: TicketsCoordinator) {
        guard let transactionCoordinator = transactionCoordinator else {
            return
        }
        let session = transactionCoordinator.session
        let tokenStorage = transactionCoordinator.tokensStorage

        switch (paymentFlow, session.account.type) {
        case (.send, .real), (.request, _):
            let coordinator = PaymentCoordinator(
                navigationController: ticketsCoordinator.navigationController,
                flow: paymentFlow,
                session: session,
                keystore: keystore,
                storage: tokenStorage,
                ticketHolders: ticketHolders
            )
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
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
            tokensStorage: tokenStorage
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
        let alertController = UIAlertController(title: "Transaction Sent!", message: "Wait for the transaction to be mined on the network to see details.", preferredStyle: UIAlertControllerStyle.alert)
        let copyAction = UIAlertAction(title: NSLocalizedString("send.action.copy.transaction.title", value: "Copy Transaction ID", comment: ""), style: UIAlertActionStyle.default, handler: { _ in
            UIPasteboard.general.string = transaction.id
        })
        alertController.addAction(copyAction)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", value: "OK", comment: ""), style: UIAlertActionStyle.default, handler: nil))
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

    func didCancel(in coordinator: TicketsCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didPressViewRedemptionInfo(in viewController: UIViewController) {
        let controller = TicketRedemptionInfoViewController()
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
}

extension InCoordinator: TokensCoordinatorDelegate {
    func didPress(for type: PaymentFlow, in coordinator: TokensCoordinator) {
        showPaymentFlow(for: type)
    }

    func didPressStormBird(for type: PaymentFlow, token: TokenObject, in coordinator: TokensCoordinator) {
        showTicketList(for: type, token: token)
    }
}

extension InCoordinator: AlphaWalletTokensCoordinatorDelegate {
    func didPress(for type: PaymentFlow, in coordinator: AlphaWalletTokensCoordinator) {
        showPaymentFlow(for: type)
    }

    func didPressStormBird(for type: PaymentFlow, token: TokenObject, in coordinator: AlphaWalletTokensCoordinator) {
        showTicketList(for: type, token: token)
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

extension InCoordinator: AlphaWalletSettingsViewControllerDelegate {
    func didPressShowWallet(in viewController: AlphaWalletSettingsViewController) {
        showPaymentFlow(for: .request)
    }
}
