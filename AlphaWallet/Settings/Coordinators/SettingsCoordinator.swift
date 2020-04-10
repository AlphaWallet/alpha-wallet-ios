// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol SettingsCoordinatorDelegate: class, CanOpenURL {
	func didRestart(with account: Wallet, in coordinator: SettingsCoordinator)
	func didUpdateAccounts(in coordinator: SettingsCoordinator)
	func didCancel(in coordinator: SettingsCoordinator)
	func didPressShowWallet(in coordinator: SettingsCoordinator)
	func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController?
	func consoleViewController(for: SettingsCoordinator) -> UIViewController?
	func delete(account: Wallet, in coordinator: SettingsCoordinator)
}

class SettingsCoordinator: Coordinator {
	private let keystore: Keystore
	var config: Config
	private let sessions: ServerDictionary<WalletSession>
    private let promptBackupCoordinator: PromptBackupCoordinator

	private var account: Wallet {
		return sessions.anyValue.account
	}

	let navigationController: UINavigationController
	weak var delegate: SettingsCoordinatorDelegate?
	var coordinators: [Coordinator] = []

    lazy var rootViewController: SettingsViewController2 = {
            let controller = SettingsViewController2.init(keystore: keystore, account: account)
    //        let controller = SettingsViewController(keystore: keystore, account: account)
    //        controller.delegate = self
            controller.modalPresentationStyle = .pageSheet
            return controller
    }()

	init(
			navigationController: UINavigationController = NavigationController(),
			keystore: Keystore,
			config: Config,
			sessions: ServerDictionary<WalletSession>,
			promptBackupCoordinator: PromptBackupCoordinator
	) {
		self.navigationController = navigationController
		self.navigationController.modalPresentationStyle = .formSheet
		self.keystore = keystore
		self.config = config
		self.sessions = sessions
        self.promptBackupCoordinator = promptBackupCoordinator
		promptBackupCoordinator.subtlePromptDelegate = self
	}

	func start() {
		navigationController.viewControllers = [rootViewController]
	}

	@objc func showMyWalletAddress() {
		delegate?.didPressShowWallet(in: self)
	}

	func backupWallet() {
		switch account.type {
		case .real(let account):
			let coordinator = BackupCoordinator(
					navigationController: navigationController,
					keystore: keystore,
					account: account
			)
			coordinator.delegate = self
			coordinator.start()
			addCoordinator(coordinator)
		case .watch:
			break
		}
	}

	@objc func showAccounts() {
		let coordinator = AccountsCoordinator(
				config: config,
				navigationController: NavigationController(),
				keystore: keystore,
				promptBackupCoordinator: promptBackupCoordinator
		)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		switch UIDevice.current.userInterfaceIdiom {
		case .pad:
			coordinator.navigationController.modalPresentationStyle = .formSheet
		case .unspecified, .tv, .carPlay, .phone:
			coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
		}
		navigationController.present(coordinator.navigationController, animated: true, completion: nil)
	}

	@objc func showLocales() {
		let coordinator = LocalesCoordinator()
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		coordinator.localesViewController.navigationItem.largeTitleDisplayMode = .never
		navigationController.pushViewController(coordinator.localesViewController, animated: true)
	}

	func clearDappBrowserCache() {
		let coordinator = ClearDappBrowserCacheCoordinator(inViewController: rootViewController)
		coordinator.start()
		addCoordinator(coordinator)
	}

	func showEnabledServers() {
		let coordinator = EnabledServersCoordinator(navigationController: navigationController, selectedServers: config.enabledServers)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
	}

	func restart(for wallet: Wallet) {
		delegate?.didRestart(with: wallet, in: self)
	}
}

extension SettingsCoordinator: SettingsViewControllerDelegate {
	func didAction(action: AlphaWalletSettingsAction, in viewController: SettingsViewController) {
		switch action {
		case .myWalletAddress:
			showMyWalletAddress()
		case .wallets:
			showAccounts()
		case .backupWallet:
			backupWallet()
		case .locales:
			showLocales()
		case .enabledServers:
            showEnabledServers()
		case .clearDappBrowserCache:
			clearDappBrowserCache()
		}
	}

	func assetDefinitionsOverrideViewController(for: SettingsViewController) -> UIViewController? {
        return delegate?.assetDefinitionsOverrideViewController(for: self)
	}

	func consoleViewController(for: SettingsViewController) -> UIViewController? {
		return delegate?.consoleViewController(for: self)
	}
}

extension SettingsCoordinator: CanOpenURL {
	func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
		delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
	}

	func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
		delegate?.didPressViewContractWebPage(url, in: viewController)
	}

	func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
		delegate?.didPressOpenWebPage(url, in: viewController)
	}
}

extension SettingsCoordinator: AccountsCoordinatorDelegate {
	func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator) {
		delegate?.didUpdateAccounts(in: self)
	}

	func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        delegate?.delete(account: account, in: self)
        for each in sessions.values {
			TransactionsTracker(sessionID: each.sessionID).fetchingState = .initial
		}
		delegate?.didUpdateAccounts(in: self)
		guard !coordinator.accountsViewController.hasWallets else { return }
		coordinator.navigationController.dismiss(animated: true, completion: nil)
		delegate?.didCancel(in: self)
	}

	func didCancel(in coordinator: AccountsCoordinator) {
		coordinator.navigationController.dismiss(animated: true, completion: nil)
		removeCoordinator(coordinator)
	}

	func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator) {
		coordinator.navigationController.dismiss(animated: true, completion: nil)
		removeCoordinator(coordinator)
		restart(for: account)
	}
}

extension SettingsCoordinator: LocalesCoordinatorDelegate {
    func didSelect(locale: AppLocale, in coordinator: LocalesCoordinator) {
		coordinator.localesViewController.navigationController?.popViewController(animated: true)
		removeCoordinator(coordinator)
		restart(for: account)
	}
}

extension SettingsCoordinator: EnabledServersCoordinatorDelegate {
	func didSelectServers(servers: [RPCServer], in coordinator: EnabledServersCoordinator) {
		//Defensive. Shouldn't allow no server to be selected
		guard !servers.isEmpty else { return }

		let unchanged = config.enabledServers.sorted(by: { $0.chainID < $1.chainID }) == servers.sorted(by: { $0.chainID < $1.chainID })
        if unchanged {
			coordinator.stop()
			removeCoordinator(coordinator)
		} else {
			config.enabledServers = servers
			restart(for: account)
		}
	}

	func didSelectDismiss(in coordinator: EnabledServersCoordinator) {
		coordinator.stop()
		removeCoordinator(coordinator)
	}
}

extension SettingsCoordinator: PromptBackupCoordinatorSubtlePromptDelegate {
	var viewControllerToShowBackupLaterAlert: UIViewController {
		return rootViewController
	}

	func updatePrompt(inCoordinator coordinator: PromptBackupCoordinator) {
//		rootViewController.promptBackupWalletView = coordinator.subtlePromptView
	}
}

extension SettingsCoordinator: BackupCoordinatorDelegate {
	func didCancel(coordinator: BackupCoordinator) {
		removeCoordinator(coordinator)
	}

	func didFinish(account: EthereumAccount, in coordinator: BackupCoordinator) {
		promptBackupCoordinator.markBackupDone()
		promptBackupCoordinator.showHideCurrentPrompt()
		removeCoordinator(coordinator)
	}
}
