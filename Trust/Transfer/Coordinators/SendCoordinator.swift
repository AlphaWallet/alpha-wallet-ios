// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt
import TrustKeystore

protocol SendCoordinatorDelegate: class {
    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator)
    func didCancel(in coordinator: SendCoordinator)
}

class SendCoordinator: Coordinator {

    let transferType: TransferType
    let session: WalletSession
    let account: Account
    let navigationController: UINavigationController
    let keystore: Keystore
    let storage: TokensDataStore
    let ticketHolders: [TicketHolder]!

    var coordinators: [Coordinator] = []
    weak var delegate: SendCoordinatorDelegate?
    lazy var sendViewController: SendViewController = {
        return self.makeSendViewController()
    }()

    init(
        transferType: TransferType,
        navigationController: UINavigationController = UINavigationController(),
        session: WalletSession,
        keystore: Keystore,
        storage: TokensDataStore,
        account: Account,
        ticketHolders: [TicketHolder] = []
    ) {
        self.transferType = transferType
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.session = session
        self.account = account
        self.keystore = keystore
        self.storage = storage
        self.ticketHolders = ticketHolders
    }

    func start() {
        if navigationController.viewControllers.isEmpty {
            navigationController.viewControllers = [sendViewController]
        } else {
            navigationController.pushViewController(sendViewController, animated: true)
        }
    }

    func makeSendViewController() -> SendViewController {
        let controller = SendViewController(
            session: session,
            storage: storage,
            account: account,
            transferType: transferType,
            ticketHolders: ticketHolders
        )

        if navigationController.viewControllers.isEmpty {
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismiss))
        }
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Next", value: "Next", comment: ""),
            style: .done,
            target: controller,
            action: #selector(SendViewController.send)
        )
        switch transferType {
        case .ether(let destination):
            controller.addressRow?.value = destination?.description
            controller.addressRow?.cell.row.updateCell()
        case .token: break
        case .stormBird: break
        case .stormBirdOrder: break
        }
        controller.delegate = self
        return controller
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }
}

extension SendCoordinator: SendViewControllerDelegate {
    func didPressConfirm(transaction: UnconfirmedTransaction, transferType: TransferType, in viewController: SendViewController) {

        let configurator = TransactionConfigurator(
            session: session,
            account: account,
            transaction: transaction
        )
        let controller = ConfirmPaymentViewController(
            session: session,
            keystore: keystore,
            configurator: configurator,
            confirmType: .signThenSend
        )
        controller.didCompleted = { result in
            switch result {
            case .success(let type):
                self.delegate?.didFinish(type, in: self)
            case .failure(let error):
                self.navigationController.displayError(error: error)
            }
        }
        navigationController.pushViewController(controller, animated: true)
    }
}
