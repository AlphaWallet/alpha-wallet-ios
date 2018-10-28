// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result
import TrustKeystore

protocol TransactionCoordinatorDelegate: class, CanOpenURL {
    func didPress(for type: PaymentFlow, in coordinator: TransactionCoordinator)
    func didCancel(in coordinator: TransactionCoordinator)
}

class TransactionCoordinator: Coordinator {
    private let keystore: Keystore
    private let storage: TransactionsStorage

    lazy var rootViewController: TransactionsViewController = {
        return makeTransactionsController(with: session.account)
    }()

    lazy var dataCoordinator: TransactionDataCoordinator = {
        let coordinator = TransactionDataCoordinator(
            session: session,
            storage: storage,
            keystore: keystore
        )
        return coordinator
    }()

    weak var delegate: TransactionCoordinatorDelegate?

    let session: WalletSession
    let tokensStorage: TokensDataStore
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        session: WalletSession,
        navigationController: UINavigationController = NavigationController(),
        storage: TransactionsStorage,
        keystore: Keystore,
        tokensStorage: TokensDataStore
    ) {
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.storage = storage
        self.tokensStorage = tokensStorage

        NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: .UIApplicationWillEnterForeground, object: nil)
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    private func makeTransactionsController(with account: Wallet) -> TransactionsViewController {
        let viewModel = TransactionsViewModel()
        let controller = TransactionsViewController(
            account: account,
            dataCoordinator: dataCoordinator,
            session: session,
            tokensStorage: tokensStorage,
            viewModel: viewModel
        )
        controller.delegate = self
        return controller
    }

    func showTransaction(_ transaction: Transaction) {
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

    @objc func didEnterForeground() {
        rootViewController.fetch()
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    func stop() {
        dataCoordinator.stop()
        session.stop()
    }
}

extension TransactionCoordinator: TransactionsViewControllerDelegate {
    func didPressTransaction(transaction: Transaction, in viewController: TransactionsViewController) {
        showTransaction(transaction)
    }

    func reset() {
        delegate?.didCancel(in: self)
    }
}

extension TransactionCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, in: viewController)
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
