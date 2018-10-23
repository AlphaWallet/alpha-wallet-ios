// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore
import UIKit

protocol SettingsCoordinatorDelegate: class, CanOpenURL {
	func didRestart(with account: Wallet, in coordinator: SettingsCoordinator)
	func didUpdateAccounts(in coordinator: SettingsCoordinator)
	func didCancel(in coordinator: SettingsCoordinator)
	func didPressShowWallet(in coordinator: SettingsCoordinator)
	func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController?
}

class SettingsCoordinator: Coordinator {
	private let keystore: Keystore
	private let session: WalletSession
	private let storage: TransactionsStorage
	private let balanceCoordinator: GetBalanceCoordinator

	let navigationController: UINavigationController
	weak var delegate: SettingsCoordinatorDelegate?
	var coordinators: [Coordinator] = []

	lazy var rootViewController: SettingsViewController = {
		let controller = SettingsViewController(session: session)
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
		let coordinator = ServersCoordinator(config: session.config)
		coordinator.delegate = self
		coordinator.start()
		addCoordinator(coordinator)
		navigationController.pushViewController(coordinator.serversViewController, animated: true)
	}

	@objc func showLocales() {
		let coordinator = LocalesCoordinator(config: session.config)
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
		case .wallets:
			showAccounts()
		case .servers:
			showServers()
		case .locales:
			showLocales()
		case .RPCServer, .currency, .DAppsBrowser:
			restart(for: session.account)
		case .locale:
			restart(for: session.account)
		}
	}

	func assetDefinitionsOverrideViewController(for: SettingsViewController) -> UIViewController? {
        return delegate?.assetDefinitionsOverrideViewController(for: self)
	}
}

extension SettingsCoordinator: CanOpenURL {
	func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
		delegate?.didPressViewContractWebPage(forContract: contract, in: viewController)
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
		storage.deleteAll()
		TransactionsTracker(sessionID: session.sessionID).fetchingState = .initial
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
