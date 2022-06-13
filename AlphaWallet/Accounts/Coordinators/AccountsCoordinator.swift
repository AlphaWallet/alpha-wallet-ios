// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol AccountsCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: AccountsCoordinator)
    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator)
    func didFinishBackup(account: AlphaWallet.Address, in coordinator: AccountsCoordinator)
}

struct AccountsCoordinatorViewModel {
    var configuration: Configuration
    var animatedPresentation: Bool = false

    enum Configuration {
        case changeWallets
        case summary

        var hidesBackButton: Bool {
            switch self {
            case .changeWallets:
                return false
            case .summary:
                return true
            }
        }

        var allowsAccountDeletion: Bool {
            return true
        }

        var navigationTitle: String {
            switch self {
            case .changeWallets:
                return R.string.localizable.walletNavigationTitle()
            case .summary:
                return R.string.localizable.walletsNavigationTitle()
            }
        }
    }
}

class AccountsCoordinator: Coordinator {
    private let config: Config
    private let keystore: Keystore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let walletBalanceService: WalletBalanceService
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainResolutionServiceType
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    lazy var accountsViewController: AccountsViewController = {
        let viewModel = AccountsViewModel(keystore: keystore, config: config, configuration: self.viewModel.configuration, analyticsCoordinator: analyticsCoordinator, walletBalanceService: walletBalanceService, blockiesGenerator: blockiesGenerator, domainResolutionService: domainResolutionService)
        viewModel.allowsAccountDeletion = self.viewModel.configuration.allowsAccountDeletion

        let controller = AccountsViewController(viewModel: viewModel)
        switch self.viewModel.configuration.hidesBackButton {
        case true:
            controller.navigationItem.hidesBackButton = true
        case false:
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))
        }

        controller.navigationItem.rightBarButtonItem = UIBarButtonItem.addButton(self, selector: #selector(addWallet))
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true

        return controller
    }()

    weak var delegate: AccountsCoordinatorDelegate?
    private let viewModel: AccountsCoordinatorViewModel

    init(
        config: Config,
        navigationController: UINavigationController,
        keystore: Keystore,
        analyticsCoordinator: AnalyticsCoordinator,
        viewModel: AccountsCoordinatorViewModel,
        walletBalanceService: WalletBalanceService,
        blockiesGenerator: BlockiesGenerator,
        domainResolutionService: DomainResolutionServiceType
    ) {
        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.analyticsCoordinator = analyticsCoordinator
        self.viewModel = viewModel
        self.walletBalanceService = walletBalanceService
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService
    }

    func start() {
        accountsViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(accountsViewController, animated: viewModel.animatedPresentation)
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
        let coordinator = WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
        if case .createInstantWallet = entryPoint {
            coordinator.navigationController = navigationController
        }
        coordinator.delegate = self
        addCoordinator(coordinator)
        let showUI = coordinator.start(entryPoint)
        if showUI {
            coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
            navigationController.present(coordinator.navigationController, animated: true)
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

            if Features.default.isAvailable(.isRenameWalletEnabledWhileLongPress) {
                controller.addAction(renameAction)
            }

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
            let walletName = textField.text?.trimmed ?? ""
            strongSelf.accountsViewController.viewModel.set(walletName: walletName, for: account)
        }))

        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        alertController.addTextField(configurationHandler: { [weak self] (textField: UITextField!) -> Void in
            guard let strongSelf = self else { return }
            strongSelf.domainResolutionService.resolveEns(address: account).done { resolution in
                textField.placeholder = resolution.resolution.value
            }.cauterize()
            let walletNames = strongSelf.config.walletNames
            textField.text = walletNames[account]
        })

        navigationController.present(alertController, animated: true)
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
            accountsViewController.viewModel.reload()

            coordinator.navigationController.dismiss(animated: true)
            removeCoordinator(coordinator)
        }
    }

    func didFail(with error: Error, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }
}

extension AccountsCoordinator: BackupCoordinatorDelegate {

    func didCancel(coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }

    func didFinish(account: AlphaWallet.Address, in coordinator: BackupCoordinator) {
        delegate?.didFinishBackup(account: account, in: self)

        removeCoordinator(coordinator)
    }
}
