// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Combine
import AlphaWalletFoundation

protocol TransactionsCoordinatorDelegate: AnyObject, CanOpenURL {
}

class TransactionsCoordinator: Coordinator {
    private let analytics: AnalyticsLogger
    private let sessionsProvider: SessionsProvider
    private let transactionsService: TransactionsService
    private let tokensService: TokensProcessingPipeline
    private let tokenImageFetcher: TokenImageFetcher

    lazy var rootViewController: TransactionsViewController = {
        let viewModel = TransactionsViewModel(transactionsService: transactionsService, sessionsProvider: sessionsProvider)
        let controller = TransactionsViewController(viewModel: viewModel)
        controller.delegate = self

        return controller
    }()

    weak var delegate: TransactionsCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(analytics: AnalyticsLogger,
         sessionsProvider: SessionsProvider,
         navigationController: UINavigationController = .withOverridenBarAppearence(),
         transactionsService: TransactionsService,
         tokensService: TokensProcessingPipeline,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.tokensService = tokensService
        self.analytics = analytics
        self.sessionsProvider = sessionsProvider
        self.navigationController = navigationController
        self.transactionsService = transactionsService
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    func showTransaction(_ transactionRow: TransactionRow, navigationController: UINavigationController) {
        guard let session = sessionsProvider.session(for: transactionRow.server) else { return }

        let viewModel = TransactionDetailsViewModel(
            transactionsService: transactionsService,
            transactionRow: transactionRow,
            blockNumberProvider: session.blockNumberProvider,
            wallet: session.account,
            tokensService: tokensService,
            analytics: analytics,
            tokenImageFetcher: tokenImageFetcher)

        let controller = TransactionDetailsViewController(viewModel: viewModel)
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    //TODO duplicate of method showTransaction(_:) to display in a specific UIViewController because we are now showing transactions from outside the transactions tab. Clean up
    func showTransaction(_ transactionRow: TransactionRow, inViewController viewController: UIViewController) {
        guard let navigationController = viewController.navigationController else { return }
        showTransaction(transactionRow, navigationController: navigationController)
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
}

extension TransactionsCoordinator: TransactionsViewControllerDelegate {
    func didPressTransaction(transactionRow: TransactionRow, in viewController: TransactionsViewController) {
        showTransaction(transactionRow, navigationController: navigationController)
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
