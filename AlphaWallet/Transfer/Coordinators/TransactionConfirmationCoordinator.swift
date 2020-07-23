//
//  TransactionConfirmationCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.07.2020.
//

import UIKit

enum ConfirmationType {
    case deposit(address: AlphaWallet.Address)
}

protocol TransactionConfirmationCoordinatorDelegate: class {
    func didCompleteTransaction(in coordinator: TransactionConfirmationCoordinator)
}

class TransactionConfirmationCoordinator: Coordinator {

    private let navigationController: UINavigationController
    private let confirmationType: ConfirmationType

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionConfirmationCoordinatorDelegate?

    init(navigationController: UINavigationController, confirmationType: ConfirmationType) {
        self.confirmationType = confirmationType
        self.navigationController = navigationController
    }

    func start() {
        let viewModel = TransactionConfirmationViewModel(confirmationType: confirmationType)
        let controller = TransactionConfirmationViewController(viewModel: viewModel)
        controller.delegate = self
        let transitionController = ConfirmationTransitionController(sourceViewController: navigationController, destinationViewController: controller)

        transitionController.start()
    }
}

extension TransactionConfirmationCoordinator: TransactionConfirmationViewControllerDelegate {

    func transactionConfirmationDidComplete(in controller: TransactionConfirmationViewController) {
        //NOTE: for sign transaction we will need to call unlock with Face ID
        delegate?.didCompleteTransaction(in: self)
    }
}
