// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

protocol InitialWalletCreationCoordinatorDelegate: class {
    func didCancel(in coordinator: InitialWalletCreationCoordinator)
    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator)
}

class InitialWalletCreationCoordinator: Coordinator {

    let navigationController: UINavigationController
    let keystore: Keystore
    var coordinators: [Coordinator] = []
    weak var delegate: InitialWalletCreationCoordinatorDelegate?
    let entryPoint: WalletEntryPoint

    init(
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        entryPoint: WalletEntryPoint
    ) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.entryPoint = entryPoint
    }

    func start() {
        switch entryPoint {
        case .createInstantWallet, .welcome:
            showCreateWallet()
        case .importWallet:
            presentImportWallet()
        case .backupWallet:
            break
        }
    }

    func showCreateWallet() {
        let coordinator = WalletCoordinator(navigationController: self.navigationController, keystore: keystore)
        coordinator.delegate = self
        coordinator.start(entryPoint)
        addCoordinator(coordinator)
    }

    func presentImportWallet() {
        let coordinator = WalletCoordinator(keystore: keystore)
        coordinator.delegate = self
        coordinator.start(entryPoint)
        navigationController.present(coordinator.navigationController, animated: true, completion: nil)
        addCoordinator(coordinator)
    }
}

extension InitialWalletCreationCoordinator: WalletCoordinatorDelegate {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        delegate?.didAddAccount(account, in: self)
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        delegate?.didCancel(in: self)
        removeCoordinator(coordinator)
    }
}
