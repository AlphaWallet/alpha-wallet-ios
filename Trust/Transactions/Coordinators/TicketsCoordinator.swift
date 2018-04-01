//
//  TicketsCoordinator.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/27/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import Result
import TrustKeystore

protocol TicketsCoordinatorDelegate: class {
    func didPressTransfer(for type: PaymentFlow,
                          ticketHolders: [TicketHolder],
                          in coordinator: TicketsCoordinator)
    func didPressRedeem(for token: TokenObject,
                        in coordinator: TicketsCoordinator)
    func didCancel(in coordinator: TicketsCoordinator)
    func didPressViewRedemptionInfo(in: UIViewController)
}

class TicketsCoordinator: Coordinator {

    private let keystore: Keystore
    var token: TokenObject!
    var type: PaymentFlow!
    lazy var rootViewController: TicketsViewController = {
        return self.makeTicketsViewController(with: self.session.account)
    }()

    weak var delegate: TicketsCoordinatorDelegate?

    let session: WalletSession
    let tokensStorage: TokensDataStore
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
        session: WalletSession,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        tokensStorage: TokensDataStore
    ) {
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokensStorage = tokensStorage
    }

    func start() {
        let viewModel = TicketsViewModel(
            token: token
        )
        rootViewController.tokenObject = token
        rootViewController.configure(viewModel: viewModel)
        navigationController.viewControllers = [rootViewController]
    }

    private func makeTicketsViewController(with account: Wallet) -> TicketsViewController {
        let controller = TicketsViewController()
        controller.account = account
        controller.session = session
        controller.tokensStorage = tokensStorage
        controller.delegate = self
        return controller
    }

    func stop() {
        session.stop()
    }

    func showRedeemViewController() {
        let redeemViewController = makeRedeemTicketsViewController()
        navigationController.pushViewController(redeemViewController, animated: true)
    }

    private func showQuantityViewController(for ticketHolder: TicketHolder,
                                            in viewController: UIViewController) {
        let quantityViewController = makeQuantitySelectionViewController(for: ticketHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func showTicketRedemptionViewController(for ticketHolder: TicketHolder,
                                                    in viewController: UIViewController) {
        let quantityViewController = makeTicketRedemptionViewController(for: ticketHolder)
        viewController.navigationController?.pushViewController(quantityViewController, animated: true)
    }

    private func makeRedeemTicketsViewController() -> RedeemTicketsViewController {
        let controller = RedeemTicketsViewController()
        let viewModel = RedeemTicketsViewModel(token: token)
        controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeQuantitySelectionViewController(for ticketHolder: TicketHolder) -> QuantitySelectionViewController {
        let controller = QuantitySelectionViewController()
        let viewModel = QuantitySelectionViewModel(ticketHolder: ticketHolder)
		controller.configure(viewModel: viewModel)
        controller.delegate = self
        return controller
    }

    private func makeTicketRedemptionViewController(for ticketHolder: TicketHolder) -> TicketRedemptionViewController {
        let controller = TicketRedemptionViewController(session: session)
        let viewModel = TicketRedemptionViewModel(ticketHolder: ticketHolder)
		controller.configure(viewModel: viewModel)
        return controller
    }

}

extension TicketsCoordinator: TicketsViewControllerDelegate {
    func didPressRedeem(token: TokenObject, in viewController: UIViewController) {
        delegate?.didPressRedeem(for: token, in: self)
    }

    func didPressSell(token: TokenObject, in viewController: UIViewController) {
        UIAlertController.alert(title: "",
                                message: "This feature is not yet implemented",
                                alertButtonTitles: ["OK"],
                                alertButtonStyles: [.cancel],
                                viewController: viewController,
                                completion: nil)
    }

    func didPressTransfer(for type: PaymentFlow, ticketHolders: [TicketHolder], in viewController: UIViewController) {
        delegate?.didPressTransfer(for: type, ticketHolders: ticketHolders, in: self)
    }

    func didCancel(in viewController: UIViewController) {
        delegate?.didCancel(in: self)
    }

    func didPressViewRedemptionInfo(viewController: UIViewController) {
       delegate?.didPressViewRedemptionInfo(in: viewController)
    }
}

extension TicketsCoordinator: RedeemTicketsViewControllerDelegate {
    func didSelectTicketHolder(ticketHolder: TicketHolder, in viewController: UIViewController) {
        showQuantityViewController(for: ticketHolder, in: viewController)
    }
}

extension TicketsCoordinator: QuantitySelectionViewControllerDelegate {
    func didSelectQuantity(ticketHolder: TicketHolder, in viewController: UIViewController) {
        showTicketRedemptionViewController(for: ticketHolder, in: viewController)
    }
}
