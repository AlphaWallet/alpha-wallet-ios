// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol PromptBackupCoordinatorDelegate: class {
    func viewControllerForPresenting(in coordinator: PromptBackupCoordinator) -> UIViewController?
    func didFinish(in coordinator: PromptBackupCoordinator)
}

///We allow user to switch wallets, so it's important to know which wallet we are prompting for. It might not be the current wallet
class PromptBackupCoordinator: Coordinator {
    private let keystore: Keystore
    private var walletAddress: AlphaWallet.Address
    private let config: Config

    var coordinators: [Coordinator] = []
    weak var delegate: PromptBackupCoordinatorDelegate?

    init(keystore: Keystore, walletAddress: AlphaWallet.Address, config: Config) {
        self.keystore = keystore
        self.walletAddress = walletAddress
        self.config = config
    }

    func start() {
        guard let vc = delegate?.viewControllerForPresenting(in: self) else {
            finish()
            return
        }
        let coordinator = WalletCoordinator(config: config, keystore: keystore)
        coordinator.delegate = self
        let proceed = coordinator.start(.backupWallet(address: walletAddress))
        guard proceed else {
            finish()
            return
        }
        vc.present(coordinator.navigationController, animated: true, completion: nil)
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
