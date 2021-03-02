// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

enum RestartReason {
    case walletChange
    case changeLocalization
    case serverChange
}

protocol SettingsCoordinatorDelegate: class, CanOpenURL {
    func didRestart(with account: Wallet, in coordinator: SettingsCoordinator, reason: RestartReason)
	func didUpdateAccounts(in coordinator: SettingsCoordinator)
	func didCancel(in coordinator: SettingsCoordinator)
	func didPressShowWallet(in coordinator: SettingsCoordinator)
	func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController?
    func showConsole(in coordinator: SettingsCoordinator)
	func delete(account: Wallet, in coordinator: SettingsCoordinator)
}

class SettingsCoordinator: Coordinator {
	private let keystore: Keystore
	private var config: Config
	private let sessions: ServerDictionary<WalletSession>
    private let promptBackupCoordinator: PromptBackupCoordinator
	private let analyticsCoordinator: AnalyticsCoordinator

	private var account: Wallet {
		return sessions.anyValue.account
	}

	let navigationController: UINavigationController
	weak var delegate: SettingsCoordinatorDelegate?
	var coordinators: [Coordinator] = []

	lazy var rootViewController: SettingsViewController = {
		let controller = SettingsViewController(config: config, keystore: keystore, account: account, analyticsCoordinator: analyticsCoordinator)
		controller.delegate = self
		controller.modalPresentationStyle = .pageSheet
		return controller
	}()

    lazy var advancedSettingsViewController: AdvancedSettingsViewController = {
        let controller = AdvancedSettingsViewController()
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        return controller
    }()

	init(
        navigationController: UINavigationController = UINavigationController(),
        keystore: Keystore,
        config: Config,
        sessions: ServerDictionary<WalletSession>,
        promptBackupCoordinator: PromptBackupCoordinator,
        analyticsCoordinator: AnalyticsCoordinator
	) {
		self.navigationController = navigationController
		self.navigationController.modalPresentationStyle = .formSheet
		self.keystore = keystore
		self.config = config
		self.sessions = sessions
        self.promptBackupCoordinator = promptBackupCoordinator
		self.analyticsCoordinator = analyticsCoordinator

		promptBackupCoordinator.subtlePromptDelegate = self
	}

	func start() {
		navigationController.viewControllers = [rootViewController]
	}

    func restart(for wallet: Wallet, reason: RestartReason) {
		delegate?.didRestart(with: wallet, in: self, reason: reason)
	}
}

extension SettingsCoordinator: SupportViewControllerDelegate {

}

extension SettingsCoordinator: SettingsViewControllerDelegate {

    func settingsViewControllerHelpSelected(in controller: SettingsViewController) {
        let viewController = SupportViewController()
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }

    func settingsViewControllerChangeWalletSelected(in controller: SettingsViewController) {
        let coordinator = AccountsCoordinator(
                config: config,
                navigationController: navigationController,
                keystore: keystore,
                promptBackupCoordinator: promptBackupCoordinator,
				analyticsCoordinator: analyticsCoordinator
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func settingsViewControllerMyWalletAddressSelected(in controller: SettingsViewController) {
        delegate?.didPressShowWallet(in: self)
    }

    func settingsViewControllerBackupWalletSelected(in controller: SettingsViewController) {
        switch account.type {
        case .real(let account):
            let coordinator = BackupCoordinator(
                    navigationController: navigationController,
                    keystore: keystore,
                    account: account,
					analyticsCoordinator: analyticsCoordinator
            )
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case .watch:
            break
        }
    }

    func settingsViewControllerActiveNetworksSelected(in controller: SettingsViewController) {
        let coordinator = EnabledServersCoordinator(navigationController: navigationController, selectedServers: config.enabledServers)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func settingsViewControllerAdvancedSettingsSelected(in controller: SettingsViewController) {
        navigationController.pushViewController(advancedSettingsViewController, animated: true)
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
        coordinator.navigationController.popViewController(animated: true)
		delegate?.didCancel(in: self)
	}

	func didCancel(in coordinator: AccountsCoordinator) {
		coordinator.navigationController.popViewController(animated: true)
		removeCoordinator(coordinator)
	}

	func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        coordinator.navigationController.popViewController(animated: true)
		removeCoordinator(coordinator)
        restart(for: account, reason: .walletChange)
	}
}

extension SettingsCoordinator: LocalesCoordinatorDelegate {
    func didSelect(locale: AppLocale, in coordinator: LocalesCoordinator) {
		coordinator.localesViewController.navigationController?.popViewController(animated: true)
		removeCoordinator(coordinator)
        restart(for: account, reason: .changeLocalization)
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
            restart(for: account, reason: .serverChange)
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
		rootViewController.promptBackupWalletView = coordinator.subtlePromptView
	}
}

extension SettingsCoordinator: BackupCoordinatorDelegate {
	func didCancel(coordinator: BackupCoordinator) {
		removeCoordinator(coordinator)
	}

	func didFinish(account: AlphaWallet.Address, in coordinator: BackupCoordinator) {
		promptBackupCoordinator.markBackupDone()
		promptBackupCoordinator.showHideCurrentPrompt()
		removeCoordinator(coordinator)
	}
}

extension SettingsCoordinator: AdvancedSettingsViewControllerDelegate {

    func advancedSettingsViewControllerConsoleSelected(in controller: AdvancedSettingsViewController) {
        delegate?.showConsole(in: self)
    }

    func advancedSettingsViewControllerClearBrowserCacheSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = ClearDappBrowserCacheCoordinator(inViewController: rootViewController)
        coordinator.start()
        addCoordinator(coordinator)
    }

    func advancedSettingsViewControllerTokenScriptSelected(in controller: AdvancedSettingsViewController) {
        guard let controller = delegate?.assetDefinitionsOverrideViewController(for: self) else { return }
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    func advancedSettingsViewControllerChangeLanguageSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = LocalesCoordinator()
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        coordinator.localesViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(coordinator.localesViewController, animated: true)
    }

    func advancedSettingsViewControllerChangeCurrencySelected(in controller: AdvancedSettingsViewController) {

    }

    func advancedSettingsViewControllerAnalyticsSelected(in controller: AdvancedSettingsViewController) {

    }
}
