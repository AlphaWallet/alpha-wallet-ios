//
//  TransactionInProgressCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.07.2020.
//

import UIKit

protocol TransactionInProgressCoordinatorDelegate: class {
    func transactionInProgressDidDissmiss(in coordinator: TransactionInProgressCoordinator)
}

class TransactionInProgressCoordinator: Coordinator {

    private lazy var viewControllerToPresent: UINavigationController = {
        let controller = TransactionInProgressViewController(viewModel: .init())
        controller.delegate = self
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        return navigationController
    }()
    private let navigationController: UINavigationController
    //TODO fix for activities: So we switch to the aEth token after action
    let shouldSwitchToAEthToken: Bool

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionInProgressCoordinatorDelegate?

    init(navigationController: UINavigationController, shouldSwitchToAEthToken: Bool) {
        self.navigationController = navigationController
        self.shouldSwitchToAEthToken = shouldSwitchToAEthToken
    }

    func start() {
        navigationController.present(viewControllerToPresent, animated: true)
    }
}

extension TransactionInProgressCoordinator: TransactionInProgressViewControllerDelegate {

    func transactionInProgressDidDissmiss(in controller: TransactionInProgressViewController) {
        viewControllerToPresent.dismiss(animated: false) {
            self.delegate?.transactionInProgressDidDissmiss(in: self)
        }
    }

    func controller(_ controller: TransactionInProgressViewController, okButtonSelected sender: UIButton) {
        viewControllerToPresent.dismiss(animated: false) {
            self.delegate?.transactionInProgressDidDissmiss(in: self)
        }
    }
}
