//
//  EditPriceAlertCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import AlphaWalletFoundation

protocol EditPriceAlertCoordinatorDelegate: class {
    func didClose(in coordinator: EditPriceAlertCoordinator)
    func didUpdateAlert(in coordinator: EditPriceAlertCoordinator)
}

class EditPriceAlertCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private let configuration: EditPriceAlertViewModel.Configuration
    private let navigationController: UINavigationController
    private let token: Token
    private let session: WalletSession
    private let alertService: PriceAlertServiceType
    private let tokensService: TokenViewModelState
    weak var delegate: EditPriceAlertCoordinatorDelegate?

    init(navigationController: UINavigationController, configuration: EditPriceAlertViewModel.Configuration, token: Token, session: WalletSession, tokensService: TokenViewModelState, alertService: PriceAlertServiceType) {
        self.configuration = configuration
        self.navigationController = navigationController
        self.token = token
        self.session = session
        self.alertService = alertService
        self.tokensService = tokensService
    }

    func start() {
        let viewModel = EditPriceAlertViewModel(configuration: configuration, token: token, tokensService: tokensService, alertService: alertService)
        let viewController = EditPriceAlertViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }
}

extension EditPriceAlertCoordinator: EditPriceAlertViewControllerDelegate {

    func didClose(in viewController: EditPriceAlertViewController) {
        delegate?.didClose(in: self)
    }

    func didUpdateAlert(in viewController: EditPriceAlertViewController) {
        navigationController.popViewController(animated: true)

        delegate?.didUpdateAlert(in: self)
    }

}

