//
//  TransactionInProgressCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.07.2020.
//

import UIKit

protocol TransactionInProgressCoordinatorDelegate: class {
    func transactionInProgressDidDissmiss(in coordinator: TransactionInProgressCoordinator, transaction: TransactionInProgress)
}

enum TransactionInProgress {
    case action(TokenInstanceAction, TokenObject)

    //FIXME: not sure that its right way to determine function name
    var isDepositeToAAVE: Bool {
        switch self {
        case .action(let action, let token):
            let isETH = token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase.eip55String) && token.server == .main
            return action.name == "Deposit ETH to Aave" && isETH
        }
    }
}

class TransactionInProgressCoordinator: Coordinator {

    lazy var viewControllerToPresent: UINavigationController = {
        let controller = TransactionInProgressViewController(viewModel: .init())
        controller.delegate = self
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        return navigationController
    }()
    private let navigationController: UINavigationController
    private let transaction: TransactionInProgress

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionInProgressCoordinatorDelegate?

    init(navigationController: UINavigationController, transaction: TransactionInProgress) {
        self.navigationController = navigationController
        self.transaction = transaction
    }

    func start() {
        navigationController.present(viewControllerToPresent, animated: true)
    }
}

extension TransactionInProgressCoordinator: TransactionInProgressViewControllerDelegate {

    func transactionInProgressDidDissmiss(in controller: TransactionInProgressViewController) {
        viewControllerToPresent.dismiss(animated: true) {
            self.delegate?.transactionInProgressDidDissmiss(in: self, transaction: self.transaction)
        }
    }

    func controller(_ controller: TransactionInProgressViewController, okButtonSelected sender: UIButton) {
        viewControllerToPresent.dismiss(animated: true) {
            self.delegate?.transactionInProgressDidDissmiss(in: self, transaction: self.transaction)
        }
    }
}
