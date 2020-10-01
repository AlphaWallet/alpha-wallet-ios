// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import PromiseKit
import Result

protocol TransactionCoordinatorDelegate: class, CanOpenURL {
}

class TransactionCoordinator: Coordinator {
    private let keystore: Keystore
    private let transactionsCollection: TransactionCollection
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let sessions: ServerDictionary<WalletSession>
    private let tokensStorages: ServerDictionary<TokensDataStore>

    lazy var rootViewController: TransactionsViewController = {
        return makeTransactionsController()
    }()

    lazy var dataCoordinator: TransactionDataCoordinator = {
        let coordinator = TransactionDataCoordinator(
            sessions: sessions,
            transactionCollection: transactionsCollection,
            keystore: keystore,
            tokensStorages: tokensStorages,
            promptBackupCoordinator: promptBackupCoordinator
        )
        return coordinator
    }()

    weak var delegate: TransactionCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = NavigationController(),
        transactionsCollection: TransactionCollection,
        keystore: Keystore,
        tokensStorages: ServerDictionary<TokensDataStore>,
        promptBackupCoordinator: PromptBackupCoordinator
    ) {
        self.sessions = sessions
        self.keystore = keystore
        self.navigationController = navigationController
        self.transactionsCollection = transactionsCollection
        self.tokensStorages = tokensStorages
        self.promptBackupCoordinator = promptBackupCoordinator

        NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    private func makeTransactionsController() -> TransactionsViewController {
        let viewModel = TransactionsViewModel()
        let controller = TransactionsViewController(
            dataCoordinator: dataCoordinator,
            sessions: sessions,
            viewModel: viewModel
        )
        controller.delegate = self
        return controller
    }

    func showTransaction(_ transaction: Transaction) {
        let session = sessions[transaction.server]
        let controller = TransactionViewController(
                session: session,
                transaction: transaction,
                delegate: self
        )
        if UIDevice.current.userInterfaceIdiom == .pad {
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .formSheet
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            nav.makePresentationFullScreenForiOS13Migration()
            navigationController.present(nav, animated: true, completion: nil)
        } else {
            controller.hidesBottomBarWhenPushed = true
            controller.navigationItem.largeTitleDisplayMode = .never
            navigationController.pushViewController(controller, animated: true)
        }
    }

    //TODO duplicate of method showTransaction(_:) to display in a specific UIViewController because we are now showing transactions from outside the transactions tab. Clean up
    func showTransaction(_ transaction: Transaction, inViewController viewController: UIViewController) {
        let session = sessions[transaction.server]
        let controller = TransactionViewController(
                session: session,
                transaction: transaction,
                delegate: self
        )
        let nav = UINavigationController(rootViewController: controller)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: controller, action: #selector(dismiss))
        nav.makePresentationFullScreenForiOS13Migration()
        viewController.present(nav, animated: true, completion: nil)
    }

    func showTransaction(withId transactionId: String, server: RPCServer, inViewController viewController: UIViewController) {
        //Quite likely we should have the transaction already
        //TODO handle when we don't handle the transaction, so we must fetch it. There might not be a simple API call to just fetch a single transaction. Probably have to fetch all transactions in a single block with Etherscan?
        guard let transaction = transactionsCollection.transaction(withTransactionId: transactionId, server: server) else { return }
        showTransaction(transaction, inViewController: viewController)
    }

    @objc func didEnterForeground() {
        rootViewController.fetch()
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    func stop() {
        dataCoordinator.stop()
        //TODO seems not good to stop here because others call stop too
        for each in sessions.values {
            each.stop()
        }
    }
}

extension TransactionCoordinator: TransactionsViewControllerDelegate {
    func didPressTransaction(transaction: Transaction, in viewController: TransactionsViewController) {
        showTransaction(transaction)
    }
}

extension TransactionCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension TransactionCoordinator: TransactionViewControllerDelegate {
}
