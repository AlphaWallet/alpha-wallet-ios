//
//  ExportJsonKeystoreCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 1/12/21.
//

import Foundation
import UIKit
import AlphaWalletFoundation

@objc protocol ExportJsonKeystoreCoordinatorDelegate {
    func didComplete(in coordinator: ExportJsonKeystoreCoordinator)
    func didCancel(in coordinator: ExportJsonKeystoreCoordinator)
}

class ExportJsonKeystoreCoordinator: NSObject, Coordinator {
    private let keystore: Keystore
    private var navigationController: UINavigationController
    private weak var initialViewController: UIViewController?
    private let wallet: Wallet

    var coordinators: [Coordinator] = []
    weak var delegate: ExportJsonKeystoreCoordinatorDelegate?

    init(keystore: Keystore, wallet: Wallet, navigationController: UINavigationController) {
        self.wallet = wallet
        self.keystore = keystore
        self.navigationController = navigationController
        initialViewController = navigationController.topViewController
    }

    func start() {
        let viewModel = ExportJsonKeystorePasswordViewModel()
        let controller = ExportJsonKeystorePasswordViewController(viewModel: viewModel)
        controller.delegate = self

        navigationController.pushViewController(controller, animated: true)
    }

    private func popViewControllers() {
        guard let controller = initialViewController else { return }
        navigationController.popToViewController(controller, animated: true)
    }
}

extension ExportJsonKeystoreCoordinator: ExportJsonKeystoreFileDelegate {
    func didExport(fileUrl: URL, in viewController: UIViewController) {
        let activityViewController = UIActivityViewController(activityItems: [fileUrl], applicationActivities: nil)
        activityViewController.completionWithItemsHandler = { [navigationController] _, _, _, error in
            guard let error = error else { return }
            navigationController.displayError(error: error)
        }
        activityViewController.popoverPresentationController?.sourceView = viewController.view
        activityViewController.popoverPresentationController?.sourceRect = navigationController.view.centerRect

        navigationController.present(activityViewController, animated: true)
    }
}

extension ExportJsonKeystoreCoordinator: ExportJsonKeystorePasswordDelegate {

    func exportKeystoreButtonSelected(with password: String, in viewController: ExportJsonKeystorePasswordViewController) {
        let viewModel = ExportJsonKeystoreFileViewModel(keystore: keystore, wallet: wallet, password: password)
        let controller = ExportJsonKeystoreFileViewController(viewModel: viewModel)
        controller.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonSelected))
        ]
        controller.delegate = self

        navigationController.pushViewController(controller, animated: true)
    }

    func didCancel(in viewController: ExportJsonKeystorePasswordViewController) {
        delegate?.didCancel(in: self)
    }

    @objc private func doneButtonSelected(_ sender: UIBarButtonItem) {
        popViewControllers()
        delegate?.didComplete(in: self)
    }
}
