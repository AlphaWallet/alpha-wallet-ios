// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

protocol AccountsCoordinatorDelegate: class {
    func didCancel(in coordinator: AccountsCoordinator)
    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator)
}

class AccountsCoordinator: Coordinator {

    let navigationController: UINavigationController
    let keystore: Keystore
    let balanceCoordinator: GetBalanceCoordinator
    var coordinators: [Coordinator] = []

    lazy var accountsViewController: AccountsViewController = {
        let controller = AccountsViewController(keystore: keystore, balanceCoordinator: balanceCoordinator)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: self, action: #selector(dismiss))
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))
        controller.allowsAccountDeletion = true
        controller.delegate = self
        return controller
    }()

    weak var delegate: AccountsCoordinatorDelegate?

    init(
        navigationController: UINavigationController,
        keystore: Keystore,
        balanceCoordinator: GetBalanceCoordinator
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.keystore = keystore
        self.balanceCoordinator = balanceCoordinator
    }

    func start() {
        navigationController.pushViewController(accountsViewController, animated: false)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }

    @objc func add() {
        chooseImportOrCreateWallet()
    }

    func chooseImportOrCreateWallet() {
        UIAlertController.alert(title: nil,
                message: nil,
                alertButtonTitles: [R.string.localizable.walletCreateButtonTitle(), R.string.localizable.walletImportButtonTitle(), R.string.localizable.cancel()],
                alertButtonStyles: [.default, .default, .cancel],
                viewController: navigationController,
                preferredStyle: .actionSheet) { index in
			        if index == 0 {
                        self.showCreateWallet()
                    } else if index == 1 {
                        self.showImportWallet()
                    }
        }
	}

    func importOrCreateWallet(entryPoint: WalletEntryPoint) {
        let coordinator = WalletCoordinator(keystore: keystore)
        if case .createInstantWallet = entryPoint {
            coordinator.navigationController = navigationController
        }
        coordinator.delegate = self
        addCoordinator(coordinator)
        let showUI = coordinator.start(entryPoint)
        if showUI {
            navigationController.present(coordinator.navigationController, animated: true, completion: nil)
        }
    }

	func showCreateWallet() {
        importOrCreateWallet(entryPoint: .createInstantWallet)
    }

    func showImportWallet() {
        importOrCreateWallet(entryPoint: .importWallet)
    }

    func showInfoSheet(for account: Wallet, sender: UIView) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.popoverPresentationController?.sourceView = sender
        controller.popoverPresentationController?.sourceRect = sender.centerRect

        switch account.type {
        case .real(let account):
            let actionTitle = R.string.localizable.walletsBackupAlertSheetTitle()
            let backupKeystoreAction = UIAlertAction(title: actionTitle, style: .default) { _ in
                let coordinator = BackupCoordinator(
                    navigationController: self.navigationController,
                    keystore: self.keystore,
                    account: account
                )
                coordinator.delegate = self
                coordinator.start()
                self.addCoordinator(coordinator)
            }
            controller.addAction(backupKeystoreAction)
        case .watch:
            break
        }

        let copyAction = UIAlertAction(
            title: R.string.localizable.copyAddress(),
            style: .default
        ) { _ in
            UIPasteboard.general.string = account.address.description
        }
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }

        controller.addAction(copyAction)
        controller.addAction(cancelAction)
        navigationController.present(controller, animated: true, completion: nil)
    }
}

extension AccountsCoordinator: AccountsViewControllerDelegate {
    func didSelectAccount(account: Wallet, in viewController: AccountsViewController) {
        delegate?.didSelectAccount(account: account, in: self)
    }

    func didDeleteAccount(account: Wallet, in viewController: AccountsViewController) {
        delegate?.didDeleteAccount(account: account, in: self)
    }

    func didSelectInfoForAccount(account: Wallet, sender: UIView, in viewController: AccountsViewController) {
        showInfoSheet(for: account, sender: sender)
    }
}

extension AccountsCoordinator: WalletCoordinatorDelegate {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        delegate?.didAddAccount(account: account, in: self)
        if let delegate = delegate {
            self.removeCoordinator(coordinator)
            delegate.didSelectAccount(account: account, in: self)
        } else {
            accountsViewController.fetch()
            coordinator.navigationController.dismiss(animated: true, completion: nil)
            self.removeCoordinator(coordinator)
        }
    }

    func didFail(with error: Error, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }
}

extension AccountsCoordinator: BackupCoordinatorDelegate {
    func didCancel(coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }

    func didFinish(account: Account, in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }
}
