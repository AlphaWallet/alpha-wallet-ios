//
//  EditPriceAlertCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import AlphaWalletFoundation

protocol EditPriceAlertCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: EditPriceAlertCoordinator)
}

class EditPriceAlertCoordinator: Coordinator {
    private let configuration: EditPriceAlertViewModel.Configuration
    private let navigationController: UINavigationController
    private let token: Token
    private let session: WalletSession
    private let alertService: PriceAlertServiceType
    private let tokensService: TokenViewModelState
    private let currencyService: CurrencyService
    var coordinators: [Coordinator] = []
    weak var delegate: EditPriceAlertCoordinatorDelegate?

    init(navigationController: UINavigationController, configuration: EditPriceAlertViewModel.Configuration, token: Token, session: WalletSession, tokensService: TokenViewModelState, alertService: PriceAlertServiceType, currencyService: CurrencyService) {
        self.configuration = configuration
        self.currencyService = currencyService
        self.navigationController = navigationController
        self.token = token
        self.session = session
        self.alertService = alertService
        self.tokensService = tokensService
    }

    func start() {
        let viewModel = EditPriceAlertViewModel(configuration: configuration, token: token, tokensService: tokensService, alertService: alertService, currencyService: currencyService)
        let viewController = EditPriceAlertViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true
        viewController.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(viewController, animated: true)
    }
}

extension EditPriceAlertCoordinator: EditPriceAlertViewControllerDelegate {

    func didClose(in viewController: EditPriceAlertViewController) {
        delegate?.didClose(in: self)
    }

    func didUpdateAlert(in viewController: EditPriceAlertViewController) {
        navigationController.popViewController(animated: true)
        delegate?.didClose(in: self)
    }
}

