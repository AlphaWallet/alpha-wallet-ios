// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol PromptBackupCoordinatorDelegate: class {
    func viewControllerForPresenting(in coordinator: PromptBackupCoordinator) -> UIViewController?
    func didFinish(in coordinator: PromptBackupCoordinator)
}

class PromptBackupCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    weak var delegate: PromptBackupCoordinatorDelegate?

    func start() {
        let keystore = try! EtherKeystore()
        let coordinator = WalletCoordinator(keystore: keystore)
        coordinator.delegate = self
        let proceed = coordinator.start(.backupWallet)
        guard proceed else {
            finish()
            return
        }
        if let vc = delegate?.viewControllerForPresenting(in: self) {
            vc.present(coordinator.navigationController, animated: true, completion: nil)
        }
        addCoordinator(coordinator)
    }

    func finish() {
        delegate?.didFinish(in: self)
    }
}

extension PromptBackupCoordinator: WalletCoordinatorDelegate {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
        finish()
    }

    func didFail(with error: Error, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
        finish()
    }

    func didCancel(in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
        finish()
    }
}
