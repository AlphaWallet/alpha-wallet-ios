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
    func didComplete(coordinator: ExportJsonKeystoreCoordinator)
}

class ExportJsonKeystoreCoordinator: NSObject, Coordinator {

    var coordinators: [Coordinator] = []
    weak var delegate: ExportJsonKeystoreCoordinatorDelegate?
    private var keystore: Keystore
    private var navigationController: UINavigationController
    private weak var initialViewController: UIViewController?
    private let wallet: Wallet

    init(keystore: Keystore, wallet: Wallet, navigationController: UINavigationController) {
        self.wallet = wallet
        self.keystore = keystore
        self.navigationController = navigationController
        initialViewController = navigationController.topViewController
    }

    func start() {
        startPasswordViewController(buttonTitle: R.string.localizable.settingsAdvancedExportJSONKeystorePasswordPasswordButtonPassword())
    }

    private func startFileViewController(buttonTitle: String, password: String) {
        let controller = ExportJsonKeystoreFileViewController(viewModel: ExportJsonKeystoreFileViewModel(keystore: keystore, wallet: wallet), buttonTitle: buttonTitle, password: password)
        controller.fileDelegate = self
        navigationController.pushViewController(controller, animated: true)
    }

    private func startPasswordViewController(buttonTitle: String) {
        let controller = ExportJsonKeystorePasswordViewController(viewModel: ExportJsonKeystorePasswordViewModel(), buttonTitle: buttonTitle)
        controller.passwordDelegate = self
        navigationController.pushViewController(controller, animated: true)
    }

    private func popViewControllers() {
        if let controller = initialViewController {
            navigationController.popToViewController(controller, animated: true)
        }
    }
}

extension ExportJsonKeystoreCoordinator: ExportJsonKeystoreFileDelegate {
    func didExport(jsonData: String, in viewController: UIViewController) {
        exportJsonKeystore(jsonData: jsonData, in: viewController)
    }
    
    func didDismissFileController() {
    }
    
    func didFinish() {
        self.popViewControllers()
        delegate?.didComplete(coordinator: self)
    }

    private func exportJsonKeystore(jsonData: String, in viewController: UIViewController) {
        let fileName = "alphawallet_keystore_export_\(UUID().uuidString).json"
        let fileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try jsonData.data(using: .utf8)!.write(to: fileUrl)
        } catch {
            navigationController.displayError(error: error)
            return
        }
        let activityViewController = UIActivityViewController(activityItems: [fileUrl], applicationActivities: nil)
        activityViewController.completionWithItemsHandler = {_, _, _, activityError in
            if let error = activityError {
                self.navigationController.displayError(error: error)
            }
        }
        activityViewController.popoverPresentationController?.sourceView = viewController.view
        activityViewController.popoverPresentationController?.sourceRect = navigationController.view.centerRect
        navigationController.present(activityViewController, animated: true)
    }
}

extension ExportJsonKeystoreCoordinator: ExportJsonKeystorePasswordDelegate {
    func didRequestExportKeystore(with password: String) {
        startFileViewController(buttonTitle: R.string.localizable.settingsAdvancedExportJSONKeystoreFilePasswordButtonPassword(), password: password)
    }

    func didDismissPasswordController() {
    }
}
