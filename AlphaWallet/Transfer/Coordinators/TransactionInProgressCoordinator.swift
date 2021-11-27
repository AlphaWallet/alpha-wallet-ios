//
//  TransactionInProgressCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.07.2020.
//

import UIKit

protocol TransactionInProgressCoordinatorDelegate: AnyObject {
    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator)
}

class TransactionInProgressCoordinator: Coordinator {

    private let account: Wallet
    private lazy var viewControllerToPresent: UINavigationController = {
        let controller = TransactionInProgressViewController(viewModel: .init(account: account))
        controller.delegate = self
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        return navigationController
    }()
    private let presentingViewController: UIViewController
    var coordinators: [Coordinator] = []
    weak var delegate: TransactionInProgressCoordinatorDelegate?

    init(presentingViewController: UIViewController, account: Wallet) {
        self.presentingViewController = presentingViewController
        self.account = account
    }

    func start() {
        presentingViewController.present(viewControllerToPresent, animated: true)
    }
}

extension TransactionInProgressCoordinator: TransactionInProgressViewControllerDelegate {

    func transactionInProgressDidDismiss(in controller: TransactionInProgressViewController) {
        viewControllerToPresent.dismiss(animated: true) {
            self.delegate?.transactionInProgressDidDismiss(in: self)
        }
    }

    func controller(_ controller: TransactionInProgressViewController, okButtonSelected sender: UIButton) {
        viewControllerToPresent.dismiss(animated: true) {
            self.delegate?.transactionInProgressDidDismiss(in: self)
        }
    }
}
