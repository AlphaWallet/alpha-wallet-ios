// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import PromiseKit
import Combine
import AlphaWalletFoundation

protocol TransactionsCoordinatorDelegate: AnyObject, CanOpenURL {
}

class TransactionsCoordinator: Coordinator {
    private let analytics: AnalyticsLogger
    private let sessions: ServerDictionary<WalletSession>
    private let transactionsService: TransactionsService
    private let tokensService: TokenViewModelState
    
    lazy var rootViewController: TransactionsViewController = {
        let viewModel = TransactionsViewModel(transactionsService: transactionsService, sessions: sessions)
        let controller = TransactionsViewController(viewModel: viewModel)
        controller.delegate = self

        return controller
    }()

    weak var delegate: TransactionsCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(analytics: AnalyticsLogger,
         sessions: ServerDictionary<WalletSession>,
         navigationController: UINavigationController = .withOverridenBarAppearence(),
         transactionsService: TransactionsService,
         tokensService: TokenViewModelState) {

        self.tokensService = tokensService
        self.analytics = analytics
        self.sessions = sessions
        self.navigationController = navigationController
        self.transactionsService = transactionsService
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    func addSentTransaction(_ transaction: SentTransaction) {
        transactionsService.addSentTransaction(transaction)
    }

    private func showTransaction(_ transactionRow: TransactionRow, on navigationController: UINavigationController) {
        let session = sessions[transactionRow.server]

        let viewModel = TransactionDetailsViewModel(
            transactionsService: transactionsService,
            transactionRow: transactionRow,
            chainState: session.chainState,
            wallet: session.account,
            tokensService: tokensService,
            analytics: analytics)

        let controller = TransactionDetailsViewController(viewModel: viewModel)
        controller.delegate = self
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

    func stop() {
        transactionsService.stop()
        //TODO seems not good to stop here because others call stop too
        for each in sessions.values {
            each.stop()
        }
    }
}

extension TransactionsCoordinator: TransactionsViewControllerDelegate {
    func didPressTransaction(transactionRow: TransactionRow, in viewController: TransactionsViewController) {
        showTransaction(transactionRow, on: navigationController)
    }
}

extension TransactionsCoordinator: CanOpenURL {
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

extension TransactionsCoordinator: TransactionDetailsViewControllerDelegate {
    func didSelectShare(in viewController: TransactionDetailsViewController, item: URL, sender: UIBarButtonItem) {
        viewController.showShareActivity(fromSource: .barButtonItem(sender), with: [item])
    }

}
