// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result
import TrustKeystore

protocol TransactionCoordinatorDelegate: class, CanOpenURL {
}

class TransactionCoordinator: Coordinator {
    private let keystore: Keystore
    private let transactionsCollection: TransactionCollection

    lazy var rootViewController: TransactionsViewController = {
        return makeTransactionsController()
    }()

    lazy var dataCoordinator: TransactionDataCoordinator = {
        let coordinator = TransactionDataCoordinator(
            sessions: sessions,
            transactionCollection: transactionsCollection,
            keystore: keystore,
            tokensStorages: tokensStorages
        )
        return coordinator
    }()

    weak var delegate: TransactionCoordinatorDelegate?

    let sessions: ServerDictionary<WalletSession>
    let tokensStorages: ServerDictionary<TokensDataStore>
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = NavigationController(),
        transactionsCollection: TransactionCollection,
        keystore: Keystore,
        tokensStorages: ServerDictionary<TokensDataStore>
    ) {
        self.sessions = sessions
        self.keystore = keystore
        self.navigationController = navigationController
        self.transactionsCollection = transactionsCollection
        self.tokensStorages = tokensStorages

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
            navigationController.present(nav, animated: true, completion: nil)
        } else {
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
        viewController.present(nav, animated: true, completion: nil)
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
    func didPressViewContractWebPage(forContract contract: String, server: RPCServer, in viewController: UIViewController) {
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
