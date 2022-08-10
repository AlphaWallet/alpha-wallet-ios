//
//  EditPriceAlertCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

protocol EditPriceAlertCoordinatorDelegate: class {
    func didClose(in coordinator: EditPriceAlertCoordinator)
    func didUpdateAlert(in coordinator: EditPriceAlertCoordinator)
}

class EditPriceAlertCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private let configuration: EdiPricetAlertViewModelConfiguration
    private let navigationController: UINavigationController
    private let token: Token
    private let session: WalletSession
    private let alertService: PriceAlertServiceType
    private let tokensService: TokenViewModelState
    weak var delegate: EditPriceAlertCoordinatorDelegate?

    init(navigationController: UINavigationController, configuration: EdiPricetAlertViewModelConfiguration, token: Token, session: WalletSession, tokensService: TokenViewModelState, alertService: PriceAlertServiceType) {
        self.configuration = configuration
        self.navigationController = navigationController
        self.token = token
        self.session = session
        self.alertService = alertService
        self.tokensService = tokensService
    }

    func start() {
        let viewController = EditPriceAlertViewController(viewModel: .init(configuration: configuration, token: token), session: session, tokensService: tokensService, alertService: alertService)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true
        viewController.navigationItem.leftBarButtonItem = .backBarButton(self, selector: #selector(backSelected))

        navigationController.pushViewController(viewController, animated: true)
    }

    @objc private func backSelected(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)

        delegate?.didClose(in: self)
    }
}

extension EditPriceAlertCoordinator: EditPriceAlertViewControllerDelegate {

    func didUpdateAlert(in viewController: EditPriceAlertViewController) {
        navigationController.popViewController(animated: true)

        delegate?.didUpdateAlert(in: self)
    }

}

