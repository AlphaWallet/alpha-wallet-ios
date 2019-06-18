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

	private var account: Wallet {
		return sessions.anyValue.account
	}

	let navigationController: UINavigationController
	weak var delegate: SettingsCoordinatorDelegate?
	var coordinators: [Coordinator] = []

	lazy var rootViewController: SettingsViewController = {
		let controller = SettingsViewController(account: account)
		controller.delegate = self
		controller.modalPresentationStyle = .pageSheet
		return controller
	}()

	init(
			navigationController: UINavigationController = NavigationController(),
			keystore: Keystore,
			config: Config,
			sessions: ServerDictionary<WalletSession>
	) {
		self.navigationController = navigationController
		self.navigationController.modalPresentationStyle = .formSheet
		self.keystore = keystore
		self.config = config
		self.sessions = sessions
	}

	func start() {
		navigationController.viewControllers = [rootViewController]
	}

	@objc func showMyWalletAddress() {
		delegate?.didPressShowWallet(in: self)
	}

	@objc func showAccounts() {
		let coordinator = AccountsCoordinator(
				config: config,
				navigationController: NavigationController(),
				keystore: keystore
		)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		navigationController.present(coordinator.navigationController, animated: true, completion: nil)
	}

	@objc func showLocales() {
		let coordinator = LocalesCoordinator()
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		navigationController.pushViewController(coordinator.localesViewController, animated: true)
	}

	func showEnabledServers() {
		let coordinator = EnabledServersCoordinator(selectedServers: config.enabledServers)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		navigationController.pushViewController(coordinator.enabledServersViewController, animated: true)
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
		case .locales:
			showLocales()
		case .enabledServers:
            showEnabledServers()
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
		let unchanged = config.enabledServers.sorted(by: { $0.chainID < $1.chainID }) == servers.sorted(by: { $0.chainID < $1.chainID })
        if unchanged {
			coordinator.enabledServersViewController.navigationController?.popViewController(animated: true)
			removeCoordinator(coordinator)
		} else {
			config.enabledServers = servers
			restart(for: account)
		}
	}

	func didSelectDismiss(in coordinator: EnabledServersCoordinator) {
		coordinator.enabledServersViewController.navigationController?.popViewController(animated: true)
		removeCoordinator(coordinator)
	}
}
