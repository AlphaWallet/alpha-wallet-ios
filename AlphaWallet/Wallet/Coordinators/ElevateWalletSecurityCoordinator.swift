// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol ElevateWalletSecurityCoordinatorDelegate: class {
    func didLockWalletSuccessfully(forAccount account: EthereumAccount, inCoordinator coordinator: ElevateWalletSecurityCoordinator)
    func didCancelLock(forAccount account: EthereumAccount, inCoordinator coordinator: ElevateWalletSecurityCoordinator)
}

class ElevateWalletSecurityCoordinator: Coordinator {
    fileprivate struct Error: LocalizedError {
        var errorDescription: String?
    }

    private lazy var rootViewController: ElevateWalletSecurityViewController = {
        let controller = ElevateWalletSecurityViewController(keystore: keystore, account: account)
        controller.configure()
        controller.delegate = self
        return controller
    }()
    private let account: EthereumAccount
    private let keystore: Keystore

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: ElevateWalletSecurityCoordinatorDelegate?

    init(navigationController: UINavigationController = UINavigationController(), keystore: Keystore, account: EthereumAccount) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
    }

    func start() {
        rootViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(rootViewController, animated: true)
    }

    func end() {
        //do nothing
    }

    func endUserInterface(animated: Bool) {
        navigationController.popViewController(animated: animated)
    }
}

extension ElevateWalletSecurityCoordinator: ElevateWalletSecurityViewControllerDelegate {
    func didTapLock(inViewController viewController: ElevateWalletSecurityViewController) {
        let isSuccessful = keystore.elevateSecurity(forAccount: account)
        if isSuccessful {
            delegate?.didLockWalletSuccessfully(forAccount: account, inCoordinator: self)
        } else {
            if keystore.isUserPresenceCheckPossible {
                //do nothing. User cancelled
            } else {
                viewController.displayError(error: Error(errorDescription: R.string.localizable.keystoreAccessKeyLockFail()))
            }
        }
    }

    func didCancelLock(inViewController viewController: ElevateWalletSecurityViewController) {
        delegate?.didCancelLock(forAccount: account, inCoordinator: self)
    }
}
