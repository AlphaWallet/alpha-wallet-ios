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
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let alertService: PriceAlertServiceType
    weak var delegate: EditPriceAlertCoordinatorDelegate?

    init(navigationController: UINavigationController, configuration: EdiPricetAlertViewModelConfiguration, tokenObject: TokenObject, session: WalletSession, alertService: PriceAlertServiceType) {
        self.configuration = configuration
        self.navigationController = navigationController
        self.tokenObject = tokenObject
        self.session = session
        self.alertService = alertService
    }

    func start() {
        let viewController = EditPriceAlertViewController(viewModel: .init(configuration: configuration, tokenObject: tokenObject), session: session, alertService: alertService)
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

