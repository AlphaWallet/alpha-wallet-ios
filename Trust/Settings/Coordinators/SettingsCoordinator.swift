// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore
import UIKit

protocol SettingsCoordinatorDelegate: class {
	func didRestart(with account: Wallet, in coordinator: SettingsCoordinator)
	func didUpdateAccounts(in coordinator: SettingsCoordinator)
	func didCancel(in coordinator: SettingsCoordinator)
	func didPressShowWallet(in coordinator: SettingsCoordinator)
}

class SettingsCoordinator: Coordinator {

	let navigationController: UINavigationController
	var config: Config
	let keystore: Keystore
	let session: WalletSession
	let storage: TransactionsStorage
	let balanceCoordinator: GetBalanceCoordinator
	weak var delegate: SettingsCoordinatorDelegate?
	let pushNotificationsRegistrar = PushNotificationsRegistrar()
	var coordinators: [Coordinator] = []

	lazy var rootViewController: SettingsViewController = {
		let controller = SettingsViewController(session: session)
		controller.delegate = self
		controller.modalPresentationStyle = .pageSheet
		return controller
	}()

	init(
			navigationController: UINavigationController = NavigationController(),
            config: Config,
			keystore: Keystore,
			session: WalletSession,
			storage: TransactionsStorage,
			balanceCoordinator: GetBalanceCoordinator
	) {
		self.navigationController = navigationController
		self.config = config
		self.navigationController.modalPresentationStyle = .formSheet
		self.keystore = keystore
		self.session = session
		self.storage = storage
		self.balanceCoordinator = balanceCoordinator
	}

	func start() {
		navigationController.viewControllers = [rootViewController]
	}

	@objc func showMyWalletAddress() {
		delegate?.didPressShowWallet(in: self)
	}

	@objc func showNotificationsSettings() {
		if let url = URL(string: UIApplicationOpenSettingsURLString) {
			UIApplication.shared.open(url)
		}
	}

	@objc func showAccounts() {
		let coordinator = AccountsCoordinator(
				navigationController: NavigationController(),
				keystore: keystore,
				balanceCoordinator: balanceCoordinator
		)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		navigationController.present(coordinator.navigationController, animated: true, completion: nil)
	}

	@objc func showServers() {
		let coordinator = ServersCoordinator(config: config)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		navigationController.pushViewController(coordinator.serversViewController, animated: true)
	}

	@objc func showLocales() {
		let coordinator = LocalesCoordinator(config: config)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		navigationController.pushViewController(coordinator.localesViewController, animated: true)
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
		case .notificationsSettings:
			showNotificationsSettings()
		case .wallets:
			showAccounts()
		case .servers:
			showServers()
		case .locales:
			showLocales()
		case .RPCServer, .currency, .DAppsBrowser:
			restart(for: session.account)
		case .pushNotifications(let enabled):
			switch enabled {
			case true:
				pushNotificationsRegistrar.register()
			case false:
				pushNotificationsRegistrar.unregister()
			}
		case .locale:
			restart(for: session.account)
		}
	}
}

extension SettingsCoordinator: AccountsCoordinatorDelegate {
	func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator) {
		delegate?.didUpdateAccounts(in: self)
	}

	func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator) {
		storage.deleteAll()
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

extension SettingsCoordinator: ServersCoordinatorDelegate {
	func didSelectServer(server: RPCServer, in coordinator: ServersCoordinator) {
		coordinator.serversViewController.navigationController?.popViewController(animated: true)
		removeCoordinator(coordinator)
		restart(for: session.account)
	}
}

extension SettingsCoordinator: LocalesCoordinatorDelegate {
    func didSelect(locale: AppLocale, in coordinator: LocalesCoordinator) {
		coordinator.localesViewController.navigationController?.popViewController(animated: true)
		removeCoordinator(coordinator)
		restart(for: session.account)
	}
}
