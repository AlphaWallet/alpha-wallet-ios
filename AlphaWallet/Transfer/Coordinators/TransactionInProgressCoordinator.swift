//
//  TransactionInProgressCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.07.2020.
//

import UIKit
import AlphaWalletFoundation

protocol TransactionInProgressCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: TransactionInProgressCoordinator)
}

class TransactionInProgressCoordinator: Coordinator {

    private lazy var viewControllerToPresent: UINavigationController = {
        let controller = TransactionInProgressViewController(viewModel: .init())
        controller.delegate = self
        let navigationController = NavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        return navigationController
    }()
    private let presentingViewController: UIViewController

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionInProgressCoordinatorDelegate?

    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }

    func start() {
        presentingViewController.present(viewControllerToPresent, animated: true)
    }
}

extension TransactionInProgressCoordinator: TransactionInProgressViewControllerDelegate {

    func didDismiss(in controller: TransactionInProgressViewController) {
        viewControllerToPresent.dismiss(animated: true) {
            self.delegate?.didDismiss(in: self)
        }
    }

    func controller(_ controller: TransactionInProgressViewController, okButtonSelected sender: UIButton) {
        viewControllerToPresent.dismiss(animated: true) {
            self.delegate?.didDismiss(in: self)
        }
    }
}
