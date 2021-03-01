// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol AccountsCoordinatorDelegate: class {
    func didCancel(in coordinator: AccountsCoordinator)
    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator)
}

class AccountsCoordinator: Coordinator {

    private let config: Config
    //Only show Ether balances from mainnet for now
    private let balanceCoordinator = GetNativeCryptoCurrencyBalanceCoordinator(forServer: .main)
    private let keystore: Keystore
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let analyticsCoordinator: AnalyticsCoordinator

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    lazy var accountsViewController: AccountsViewController = {
        let controller = AccountsViewController(config: config, keystore: keystore, balanceCoordinator: balanceCoordinator)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(image: R.image.backWhite(), style: .done, target: self, action: #selector(dismiss))
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(title: R.string.localizable.addButtonTitle(), style: .plain, target: self, action: #selector(addWallet))
        controller.allowsAccountDeletion = true
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        return controller
    }()

    weak var delegate: AccountsCoordinatorDelegate?

    init(
        config: Config,
        navigationController: UINavigationController,
        keystore: Keystore,
        promptBackupCoordinator: PromptBackupCoordinator,
        analyticsCoordinator: AnalyticsCoordinator
    ) {
        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.promptBackupCoordinator = promptBackupCoordinator
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        accountsViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(accountsViewController, animated: true)
    }

    @objc private func dismiss() {
        delegate?.didCancel(in: self)
    }

    @objc private func addWallet() {
        guard let barButtonItem = accountsViewController.navigationItem.rightBarButtonItem else { return }
        UIAlertController.alert(title: nil,
                message: nil,
                alertButtonTitles: [
                    R.string.localizable.walletCreateButtonTitle(),
                    R.string.localizable.walletImportButtonTitle(),
                    R.string.localizable.walletWatchButtonTitle(),
                    R.string.localizable.cancel()
                ],
                alertButtonStyles: [
                    .default,
                    .default,
                    .default,
                    .cancel
                ],
                viewController: navigationController,
                style: .actionSheet(source: .barButtonItem(barButtonItem))) { [weak self] index in
                    guard let strongSelf = self else { return }
                    if index == 0 {
                        strongSelf.showCreateWallet()
                    } else if index == 1 {
                        strongSelf.showImportWallet()
                    } else if index == 2 {
                        strongSelf.showWatchWallet()
                    }
        }
	}

    private func importOrCreateWallet(entryPoint: WalletEntryPoint) {
        let coordinator = WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsCoordinator)
        if case .createInstantWallet = entryPoint {
            coordinator.navigationController = navigationController
        }
        coordinator.delegate = self
        addCoordinator(coordinator)
        let showUI = coordinator.start(entryPoint)
        if showUI {
            coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
            navigationController.present(coordinator.navigationController, animated: true, completion: nil)
        }

    }

    private func showInfoSheet(for account: Wallet, sender: UIView) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.popoverPresentationController?.sourceView = sender

        switch account.type {
        case .real(let account):
            let actionTitle: String
            if keystore.isHdWallet(account: account) {
                actionTitle = R.string.localizable.walletsBackupHdWalletAlertSheetTitle()
            } else {
                actionTitle = R.string.localizable.walletsBackupKeystoreWalletAlertSheetTitle()
            }
            let backupKeystoreAction = UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
                guard let strongSelf = self else { return }
                let coordinator = BackupCoordinator(navigationController: strongSelf.navigationController, keystore: strongSelf.keystore, account: account, analyticsCoordinator: strongSelf.analyticsCoordinator)
                coordinator.delegate = strongSelf
                coordinator.start()
                strongSelf.addCoordinator(coordinator)
            }
            controller.addAction(backupKeystoreAction)

            let renameAction = UIAlertAction(title: R.string.localizable.walletsNameRename(), style: .default) { [weak self] _ in
                self?.promptRenameWallet(account)
            }
            controller.addAction(renameAction)

            let copyAction = UIAlertAction(title: R.string.localizable.copyAddress(), style: .default) { _ in
                UIPasteboard.general.string = account.eip55String
            }
            controller.addAction(copyAction)

            let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }

            controller.addAction(cancelAction)

            navigationController.present(controller, animated: true)
        case .watch:
            let renameAction = UIAlertAction(title: R.string.localizable.walletsNameRename(), style: .default) { [weak self] _ in
                self?.promptRenameWallet(account.address)
            }
            controller.addAction(renameAction)

            let copyAction = UIAlertAction(title: R.string.localizable.copyAddress(), style: .default) { _ in
                UIPasteboard.general.string = account.address.eip55String
            }
            controller.addAction(copyAction)
            let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
            controller.addAction(cancelAction)

            navigationController.present(controller, animated: true)
        }
    }

    private func promptRenameWallet(_ account: AlphaWallet.Address) {
        let alertController = UIAlertController(
                title: R.string.localizable.walletsNameRenameTo(),
                message: nil,
                preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: { [weak self] _ -> Void in
            guard let strongSelf = self else { return }
            let textField = alertController.textFields![0] as UITextField
            let name = textField.text?.trimmed ?? ""
            if name.isEmpty {
                strongSelf.config.deleteWalletName(forAccount: account)
                strongSelf.accountsViewController.fetch()
            } else {
                strongSelf.config.saveWalletName(name, forAddress: account)
                strongSelf.accountsViewController.fetch()
            }
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        alertController.addTextField(configurationHandler: { [weak self] (textField: UITextField!) -> Void in
            guard let strongSelf = self else { return }
            let serverToResolveEns = RPCServer.main
            ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: account) { result in
                guard let ensName = result.value else { return }
                textField.placeholder = ensName
            }
            let walletNames = strongSelf.config.walletNames
            textField.text = walletNames[account]
        })
        navigationController.present(alertController, animated: true, completion: nil)
    }

    private func showCreateWallet() {
        importOrCreateWallet(entryPoint: .createInstantWallet)
    }

    private func showImportWallet() {
        importOrCreateWallet(entryPoint: .importWallet)
    }

    private func showWatchWallet() {
        importOrCreateWallet(entryPoint: .watchWallet(address: nil))
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
            removeCoordinator(coordinator)
            delegate.didSelectAccount(account: account, in: self)
        } else {
            accountsViewController.fetch()
            coordinator.navigationController.dismiss(animated: true, completion: nil)
            removeCoordinator(coordinator)
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

    func didFinish(account: AlphaWallet.Address, in coordinator: BackupCoordinator) {
        promptBackupCoordinator.markBackupDone()
        promptBackupCoordinator.showHideCurrentPrompt()
        removeCoordinator(coordinator)
    }
}
