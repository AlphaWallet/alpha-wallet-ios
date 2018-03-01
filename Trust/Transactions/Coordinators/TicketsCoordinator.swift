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
    func didPress(for type: PaymentFlow,
                  ticketHolders: [TicketHolder],
                  in coordinator: TicketsCoordinator)
    func didCancel(in coordinator: TicketsCoordinator)
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
        rootViewController.viewModel = viewModel
        navigationController.viewControllers = [rootViewController]
    }

    private func makeTicketsViewController(with account: Wallet) -> TicketsViewController {
        let storyboard = UIStoryboard(name: "Tickets", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "TicketsViewController") as! TicketsViewController
        controller.account = account
        controller.session = session
        controller.tokensStorage = tokensStorage
        controller.delegate = self
        return controller
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true, completion: nil)
    }

    func stop() {
        session.stop()
    }

}

extension TicketsCoordinator: TicketsViewControllerDelegate {
    func didPressRedeem(token: TokenObject, in viewController: UIViewController) {
        UIAlertController.alert(title: "",
                                message: "This feature is not yet implemented",
                                alertButtonTitles: ["OK"],
                                alertButtonStyles: [.cancel],
                                viewController: viewController,
                                completion: nil)

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
        delegate?.didPress(for: type, ticketHolders: ticketHolders, in: self)
    }

    func didCancel(in viewController: UIViewController) {
        viewController.navigationController?.dismiss(animated: true, completion: nil)
        delegate?.didCancel(in: self)
    }
}
