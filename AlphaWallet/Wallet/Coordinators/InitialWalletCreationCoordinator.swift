// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol InitialWalletCreationCoordinatorDelegate: class {
    func didCancel(in coordinator: InitialWalletCreationCoordinator)
    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator)
}

class InitialWalletCreationCoordinator: Coordinator {
    private let keystore: Keystore
    private let entryPoint: WalletEntryPoint
    private let config: Config

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: InitialWalletCreationCoordinatorDelegate?

    init(
        config: Config,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore,
        entryPoint: WalletEntryPoint
    ) {
        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.entryPoint = entryPoint
    }

    func start() {
        switch entryPoint {
        case .createInstantWallet, .welcome:
            showCreateWallet()
        case .importWallet:
            presentImportOrWatchWallet()
        case .watchWallet:
            presentImportOrWatchWallet()
        case .backupWallet:
            break
        }
    }

    func showCreateWallet() {
        let coordinator = WalletCoordinator(config: config, navigationController: navigationController, keystore: keystore)
        coordinator.delegate = self
        let _ = coordinator.start(entryPoint)
        addCoordinator(coordinator)
    }

    func presentImportOrWatchWallet() {
        let coordinator = WalletCoordinator(config: config, keystore: keystore)
        coordinator.delegate = self
        let _ = coordinator.start(entryPoint)
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
