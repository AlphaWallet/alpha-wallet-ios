// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result
import TrustKeystore

protocol TicketsCoordinatorDelegate: class {
    func didPress(for type: PaymentFlow, in coordinator: TicketsCoordinator)
    func didCancel(in coordinator: TicketsCoordinator)
}

class TicketsCoordinator: Coordinator {

    private let keystore: Keystore
    var token: TokenObject!
    var type: PaymentFlow!
    let storage: TransactionsStorage
    lazy var rootViewController: TicketsViewController = {
        return self.makeTransactionsController(with: self.session.account)
    }()

    lazy var dataCoordinator: TransactionDataCoordinator = {
        let coordinator = TransactionDataCoordinator(
                session: self.session,
                storage: self.storage
        )
        return coordinator
    }()

    weak var delegate: TicketsCoordinatorDelegate?

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
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    private func makeTransactionsController(with account: Wallet) -> TicketsViewController {
        let viewModel = TicketsViewModel(
                token: token,
                ticketHolders: TicketAdaptor.getTicketHolders(for: token)
        )

        let storyboard = UIStoryboard(name: "Tickets", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "TicketsViewController") as! TicketsViewController
        controller.account = account
        controller.dataCoordinator = dataCoordinator
        controller.session = session
        controller.viewModel = viewModel
        controller.tokensStorage = tokensStorage
        controller.delegate = self
        return controller
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    func stop() {
        dataCoordinator.stop()
        session.stop()
    }

    func showPaymentFlow(for paymentFlow: PaymentFlow, ticketHolders: [TicketHolder] = []) {
        switch (paymentFlow, session.account.type) {
        case (.send, .real), (.request, _):
            let coordinator = PaymentCoordinator(
                    navigationController: navigationController,
                    flow: paymentFlow,
                    session: session,
                    keystore: keystore,
                    storage: tokensStorage,
                    ticketHolders: ticketHolders
            )
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (_, _):
            navigationController.displayError(error: InCoordinatorError.onlyWatchAccount)
        }

    }
}

extension TicketsCoordinator: TicketsViewControllerDelegate {
    func didPressRedeem(token: TokenObject, in viewController: UIViewController) {

    }

    func didPressSell(token: TokenObject, in viewController: UIViewController) {

    }

    func didPressTransfer(ticketHolder: TicketHolder?, token: TokenObject, in viewController: UIViewController) {
        showPaymentFlow(for: type, ticketHolders: [ticketHolder!])
    }
}

extension TicketsCoordinator: PaymentCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator) {
        dismiss()
    }

    func didCancel(in coordinator: PaymentCoordinator) {

    }
}
