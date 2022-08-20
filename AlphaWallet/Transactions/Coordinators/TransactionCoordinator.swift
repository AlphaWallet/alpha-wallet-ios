// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import PromiseKit
import Combine
import AlphaWalletFoundation

protocol TransactionCoordinatorDelegate: class, CanOpenURL {
}

class TransactionCoordinator: NSObject, Coordinator {
    private let analytics: AnalyticsLogger
    private let sessions: ServerDictionary<WalletSession>
    private var cancelable = Set<AnyCancellable>()
    private var transactionsService: TransactionsService
    private let service: TokenViewModelState
    lazy var rootViewController: TransactionsViewController = {
        return makeTransactionsController()
    }()

    weak var delegate: TransactionCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        analytics: AnalyticsLogger,
        sessions: ServerDictionary<WalletSession>,
        navigationController: UINavigationController = .withOverridenBarAppearence(),
        transactionsService: TransactionsService,
        service: TokenViewModelState
    ) {
        self.service = service
        self.analytics = analytics
        self.sessions = sessions
        self.navigationController = navigationController
        self.transactionsService = transactionsService

        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        //NOTE: Reduce copies of unused transaction instances, `TransactionsViewController` isn't using when activities enabled.
        guard !Features.default.isAvailable(.isActivityEnabled) else { return }

        transactionsService
            .transactionsChangeset
            .map { TransactionsViewModel.mapTransactions(transactions: $0) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.rootViewController.configure(viewModel: .init(transactions: transactions))
            }.store(in: &cancelable)
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    func addSentTransaction(_ transaction: SentTransaction) {
        transactionsService.addSentTransaction(transaction)
    }

    private func makeTransactionsController() -> TransactionsViewController {
        let viewModel = TransactionsViewModel()
        let controller = TransactionsViewController(dataCoordinator: transactionsService, sessions: sessions, viewModel: viewModel)
        controller.delegate = self

        return controller
    }

    private func showTransaction(_ transactionRow: TransactionRow, on navigationController: UINavigationController) {
        let controller = TransactionViewController(analytics: analytics, session: sessions[transactionRow.server], transactionRow: transactionRow, service: service, delegate: self)
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    //TODO duplicate of method showTransaction(_:) to display in a specific UIViewController because we are now showing transactions from outside the transactions tab. Clean up
    func showTransaction(_ transactionRow: TransactionRow, inViewController viewController: UIViewController) {
        guard let navigationController = viewController.navigationController else { return }
        showTransaction(transactionRow, on: navigationController)
    }

    func showTransaction(withId transactionId: String, server: RPCServer, inViewController viewController: UIViewController) {
        //Quite likely we should have the transaction already
        //TODO handle when we don't handle the transaction, so we must fetch it. There might not be a simple API call to just fetch a single transaction. Probably have to fetch all transactions in a single block with Etherscan?
        guard let transaction = transactionsService.transaction(withTransactionId: transactionId, forServer: server) else { return }
        if transaction.localizedOperations.count > 1 {
            showTransaction(.group(transaction), inViewController: viewController)
        } else {
            showTransaction(.standalone(transaction), inViewController: viewController)
        }
    }

    @objc func didEnterForeground() {
        rootViewController.fetch()
    }

    func stop() {
        transactionsService.stop()
        //TODO seems not good to stop here because others call stop too
        for each in sessions.values {
            each.stop()
        }
    }
}

extension TransactionCoordinator: TransactionsViewControllerDelegate {
    func didPressTransaction(transactionRow: TransactionRow, in viewController: TransactionsViewController) {
        showTransaction(transactionRow, on: navigationController)
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
