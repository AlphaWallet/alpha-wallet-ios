// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

enum RestartReason {
    case walletChange
    case changeLocalization
    case serverChange
}

protocol SettingsCoordinatorDelegate: class, CanOpenURL {
    func didRestart(with account: Wallet, in coordinator: SettingsCoordinator, reason: RestartReason)
	func didCancel(in coordinator: SettingsCoordinator)
	func didPressShowWallet(in coordinator: SettingsCoordinator)
	func assetDefinitionsOverrideViewController(for: SettingsCoordinator) -> UIViewController?
    func showConsole(in coordinator: SettingsCoordinator)
    func restartToReloadServersQueued(in coordinator: SettingsCoordinator)
}

class SettingsCoordinator: Coordinator {
	private let keystore: Keystore
	private var config: Config
	private let sessions: ServerDictionary<WalletSession>
    private let restartQueue: RestartTaskQueue
    private let promptBackupCoordinator: PromptBackupCoordinator
	private let analytics: AnalyticsLogger
    private let walletConnectCoordinator: WalletConnectCoordinator
    private let walletBalanceService: WalletBalanceService
    private let blockscanChatService: BlockscanChatService
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainResolutionServiceType
	private var account: Wallet {
		return sessions.anyValue.account
	}
    private let lock: Lock
    weak private var advancedSettingsViewController: AdvancedSettingsViewController?

	let navigationController: UINavigationController
	weak var delegate: SettingsCoordinatorDelegate?
	var coordinators: [Coordinator] = []

	lazy var rootViewController: SettingsViewController = {
        let viewModel = SettingsViewModel(account: account, keystore: keystore, lock: lock, config: config, analytics: analytics, domainResolutionService: domainResolutionService)
		let controller = SettingsViewController(viewModel: viewModel)
		controller.delegate = self
		return controller
	}()

    init(
        navigationController: UINavigationController = .withOverridenBarAppearence(),
        keystore: Keystore,
        config: Config,
        sessions: ServerDictionary<WalletSession>,
        restartQueue: RestartTaskQueue,
        promptBackupCoordinator: PromptBackupCoordinator,
        analytics: AnalyticsLogger,
        walletConnectCoordinator: WalletConnectCoordinator,
        walletBalanceService: WalletBalanceService,
        blockscanChatService: BlockscanChatService,
        blockiesGenerator: BlockiesGenerator,
        domainResolutionService: DomainResolutionServiceType,
        lock: Lock
	) {
		self.navigationController = navigationController
        self.lock = lock
        self.keystore = keystore
		self.config = config
		self.sessions = sessions
        self.restartQueue = restartQueue
        self.promptBackupCoordinator = promptBackupCoordinator
		self.analytics = analytics
        self.walletConnectCoordinator = walletConnectCoordinator
        self.walletBalanceService = walletBalanceService
        self.blockscanChatService = blockscanChatService
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService
		promptBackupCoordinator.subtlePromptDelegate = self
	}

	func start() {
		navigationController.viewControllers = [rootViewController]
	}

    func restart(for wallet: Wallet, reason: RestartReason) {
		delegate?.didRestart(with: wallet, in: self, reason: reason)
	}

    private func showTools(in controller: AdvancedSettingsViewController) {
        let controller = ToolsViewController(config: config)
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }

    func showBlockscanChatUnreadCount(_ count: Int?) {
        rootViewController.configure(blockscanChatUnreadCount: count)
    }
}

extension SettingsCoordinator: SupportViewControllerDelegate {

}

extension SettingsCoordinator: RenameWalletViewControllerDelegate {

    func didFinish(in viewController: RenameWalletViewController) {
        navigationController.popViewController(animated: true)
    }
}

extension SettingsCoordinator: SettingsViewControllerDelegate {

    func settingsViewControllerNameWalletSelected(in controller: SettingsViewController) {
        let viewModel = RenameWalletViewModel(account: account.address, analytics: analytics, domainResolutionService: domainResolutionService)

        let viewController = RenameWalletViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }

    func settingsViewControllerBlockscanChatSelected(in controller: SettingsViewController) {
        blockscanChatService.openBlockscanChat(forAddress: account.address)
    }

    func settingsViewControllerWalletConnectSelected(in controller: SettingsViewController) {
        walletConnectCoordinator.showSessions()
    }

    func settingsViewControllerShowSeedPhraseSelected(in controller: SettingsViewController) {
        switch account.type {
        case .real(let account):
            let coordinator = ShowSeedPhraseCoordinator(navigationController: navigationController, keystore: keystore, account: account)
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case .watch:
            break
        }
    }

    func settingsViewControllerHelpSelected(in controller: SettingsViewController) {
        let viewController = SupportViewController(analytics: analytics)
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
				analytics: analytics,
                viewModel: .init(configuration: .changeWallets, animatedPresentation: true),
                walletBalanceService: walletBalanceService,
                blockiesGenerator: blockiesGenerator,
                domainResolutionService: domainResolutionService
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
        case .real:
            let coordinator = BackupCoordinator(
                    navigationController: navigationController,
                    keystore: keystore,
                    account: account,
					analytics: analytics
            )
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case .watch:
            break
        }
    }

    func settingsViewControllerActiveNetworksSelected(in controller: SettingsViewController) {
        let coordinator = EnabledServersCoordinator(navigationController: navigationController, selectedServers: config.enabledServers, restartQueue: restartQueue, analytics: analytics)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func settingsViewControllerAdvancedSettingsSelected(in controller: SettingsViewController) {
        let controller = AdvancedSettingsViewController(wallet: account, config: config)
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
        advancedSettingsViewController = controller
    }
}

extension SettingsCoordinator: ShowSeedPhraseCoordinatorDelegate {
    func didCancel(in coordinator: ShowSeedPhraseCoordinator) {
        removeCoordinator(coordinator)
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

    func didFinishBackup(account: AlphaWallet.Address, in coordinator: AccountsCoordinator) {
        promptBackupCoordinator.markBackupDone()
        promptBackupCoordinator.showHideCurrentPrompt()
    }

	func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        //no-op
	}

	func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        guard !coordinator.accountsViewController.viewModel.hasWallets else { return }
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
        if self.account == account {
            //no-op
        } else {
            restart(for: account, reason: .walletChange)
        }
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

    func restartToReloadServersQueued(in coordinator: EnabledServersCoordinator) {
        delegate?.restartToReloadServersQueued(in: self)
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
    func advancedSettingsViewControllerMoreSelected(in controller: AdvancedSettingsViewController) {
        showTools(in: controller)
    }

    func advancedSettingsViewControllerClearBrowserCacheSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = ClearDappBrowserCacheCoordinator(inViewController: rootViewController, analytics: analytics)
        coordinator.delegate = self
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
        let controller = AnalyticsViewController(viewModel: .init(isSendAnalyticsEnabled: config.isSendAnalyticsEnabled), config: config)
        navigationController.pushViewController(controller, animated: true)
    }

    func advancedSettingsViewControllerUsePrivateNetworkSelected(in controller: AdvancedSettingsViewController) {
        let controller = ChooseSendPrivateTransactionsProviderViewController(config: config)
        controller.delegate = self
        navigationController.pushViewController(controller, animated: true)
    }

    func advancedSettingsViewControllerExportJSONKeystoreSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = ExportJsonKeystoreCoordinator(keystore: keystore, wallet: account, navigationController: navigationController)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func advancedSettingsViewControllerFeaturesSelected(in controller: AdvancedSettingsViewController) {
        let controller = FeaturesViewController()
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }

}

extension SettingsCoordinator: ChooseSendPrivateTransactionsProviderViewControllerDelegate {
    func privateTransactionProviderSelected(provider: SendPrivateTransactionsProvider?, inController viewController: ChooseSendPrivateTransactionsProviderViewController) {
        advancedSettingsViewController?.configure()
    }
}

extension SettingsCoordinator: PingInfuraCoordinatorDelegate {
    func didPing(in coordinator: PingInfuraCoordinator) {
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: PingInfuraCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: CheckTransactionStateCoordinatorDelegate {
    func didComplete(coordinator: CheckTransactionStateCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: ExportJsonKeystoreCoordinatorDelegate {
    func didComplete(coordinator: ExportJsonKeystoreCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: ClearDappBrowserCacheCoordinatorDelegate {
    func done(in coordinator: ClearDappBrowserCacheCoordinator) {
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: ClearDappBrowserCacheCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: ToolsViewControllerDelegate {
    func toolsCheckTransactionStateSelected(in controller: ToolsViewController) {
        let coordinator = CheckTransactionStateCoordinator(navigationController: navigationController, config: config)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func toolsConsoleSelected(in controller: ToolsViewController) {
        delegate?.showConsole(in: self)
    }

    func toolsPingInfuraSelected(in controller: ToolsViewController) {
        let coordinator = PingInfuraCoordinator(inViewController: controller, analytics: analytics)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}
