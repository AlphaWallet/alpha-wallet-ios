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

