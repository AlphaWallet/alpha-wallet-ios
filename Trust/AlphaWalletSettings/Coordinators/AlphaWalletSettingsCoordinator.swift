// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore
import UIKit

//Duplicated from SettingsCoordinator.swift for easier upstream merging
protocol AlphaWalletSettingsCoordinatorDelegate: class {
	func didRestart(with account: Wallet, in coordinator: AlphaWalletSettingsCoordinator)
	func didUpdateAccounts(in coordinator: AlphaWalletSettingsCoordinator)
	func didCancel(in coordinator: AlphaWalletSettingsCoordinator)
	func didPressShowWallet(in coordinator: AlphaWalletSettingsCoordinator)
}

class AlphaWalletSettingsCoordinator: Coordinator {

	let navigationController: UINavigationController
	let keystore: Keystore
	let session: WalletSession
	let storage: TransactionsStorage
	let balanceCoordinator: GetBalanceCoordinator
	weak var delegate: AlphaWalletSettingsCoordinatorDelegate?
	let pushNotificationsRegistrar = PushNotificationsRegistrar()
	var coordinators: [Coordinator] = []

	lazy var rootViewController: AlphaWalletSettingsViewController = {
		let controller = AlphaWalletSettingsViewController(session: session)
		controller.delegate = self
		controller.modalPresentationStyle = .pageSheet
		return controller
	}()

	init(
			navigationController: UINavigationController = NavigationController(),
			keystore: Keystore,
			session: WalletSession,
			storage: TransactionsStorage,
			balanceCoordinator: GetBalanceCoordinator
	) {
		self.navigationController = navigationController
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

	func restart(for wallet: Wallet) {
		delegate?.didRestart(with: wallet, in: self)
	}
}

extension AlphaWalletSettingsCoordinator: AlphaWalletSettingsViewControllerDelegate {
	func didAction(action: AlphaWalletSettingsAction, in viewController: AlphaWalletSettingsViewController) {
		switch action {
		case .myWalletAddress:
			showMyWalletAddress()
		case .notificationsSettings:
			showNotificationsSettings()
		case .wallets:
			showAccounts()
		case .RPCServer, .currency, .DAppsBrowser:
			restart(for: session.account)
		case .pushNotifications(let enabled):
			switch enabled {
			case true:
				pushNotificationsRegistrar.register()
			case false:
				pushNotificationsRegistrar.unregister()
			}
		}
	}
}

extension AlphaWalletSettingsCoordinator: AccountsCoordinatorDelegate {
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
