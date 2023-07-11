// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import AlphaWalletNotifications

enum RestartReason {
    case walletChange
    case changeLocalization
    case serverChange
    case currencyChange
}

protocol SettingsCoordinatorDelegate: AnyObject, CanOpenURL {
    func didRestart(with account: Wallet, in coordinator: SettingsCoordinator, reason: RestartReason)
    func didCancel(in coordinator: SettingsCoordinator)
    func didPressShowWallet(in coordinator: SettingsCoordinator)
    func showConsole(in coordinator: SettingsCoordinator)
}

class SettingsCoordinator: Coordinator {
    private let keystore: Keystore
    private var config: Config
    private let sessionsProvider: SessionsProvider
    private let restartHandler: RestartQueueHandler
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let analytics: AnalyticsLogger
    private let walletConnectCoordinator: WalletConnectCoordinator
    private let walletBalanceService: WalletBalanceService
    private let blockscanChatService: BlockscanChatService
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainNameResolutionServiceType
    private var account: Wallet {
        return sessionsProvider.activeSessions.anyValue.account
    }
    private let lock: Lock
    private let currencyService: CurrencyService
    private let tokenScriptOverridesFileManager: TokenScriptOverridesFileManager
    private let networkService: NetworkService
    private let promptBackup: PromptBackup
    private let serversProvider: ServersProvidable
    private let pushNotificationsService: PushNotificationsService

    let navigationController: UINavigationController
    weak var delegate: SettingsCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    lazy var rootViewController: SettingsViewController = {
        let viewModel = SettingsViewModel(
            account: account,
            lock: lock,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            promptBackup: promptBackup,
            pushNotificationsService: pushNotificationsService)

        let controller = SettingsViewController(viewModel: viewModel)
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .always

        return controller
    }()

    init(navigationController: UINavigationController = .withOverridenBarAppearence(),
         keystore: Keystore,
         config: Config,
         sessionsProvider: SessionsProvider,
         restartHandler: RestartQueueHandler,
         promptBackupCoordinator: PromptBackupCoordinator,
         analytics: AnalyticsLogger,
         walletConnectCoordinator: WalletConnectCoordinator,
         walletBalanceService: WalletBalanceService,
         blockscanChatService: BlockscanChatService,
         blockiesGenerator: BlockiesGenerator,
         domainResolutionService: DomainNameResolutionServiceType,
         lock: Lock,
         currencyService: CurrencyService,
         tokenScriptOverridesFileManager: TokenScriptOverridesFileManager,
         networkService: NetworkService,
         promptBackup: PromptBackup,
         serversProvider: ServersProvidable,
         pushNotificationsService: PushNotificationsService) {

        self.pushNotificationsService = pushNotificationsService
        self.serversProvider = serversProvider
        self.promptBackup = promptBackup
        self.networkService = networkService
        self.tokenScriptOverridesFileManager = tokenScriptOverridesFileManager
        self.navigationController = navigationController
        self.lock = lock
        self.keystore = keystore
        self.config = config
        self.sessionsProvider = sessionsProvider
        self.restartHandler = restartHandler
        self.promptBackupCoordinator = promptBackupCoordinator
        self.analytics = analytics
        self.walletConnectCoordinator = walletConnectCoordinator
        self.walletBalanceService = walletBalanceService
        self.blockscanChatService = blockscanChatService
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService
        self.currencyService = currencyService
        promptBackupCoordinator.subtlePromptDelegate = self
    }

    func start() {
        navigationController.viewControllers = [rootViewController]
    }

    func restart(for wallet: Wallet, reason: RestartReason) {
        delegate?.didRestart(with: wallet, in: self, reason: reason)
    }

    func showBlockscanChatUnreadCount(_ count: Int?) {
        rootViewController.configure(blockscanChatUnreadCount: count)
    }
}

extension SettingsCoordinator: RenameWalletViewControllerDelegate {

    func didFinish(in viewController: RenameWalletViewController) {
        navigationController.popViewController(animated: true)
    }
}

extension SettingsCoordinator: LockCreatePasscodeCoordinatorDelegate {
    func didClose(in coordinator: LockCreatePasscodeCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: SettingsViewControllerDelegate {

    func createPasswordSelected(in controller: SettingsViewController) {
        let coordinator = LockCreatePasscodeCoordinator(navigationController: navigationController, lock: lock)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func nameWalletSelected(in controller: SettingsViewController) {
        let viewModel = RenameWalletViewModel(account: account.address, analytics: analytics, domainResolutionService: domainResolutionService)
        let viewController = RenameWalletViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }

    func blockscanChatSelected(in controller: SettingsViewController) {
        blockscanChatService.openBlockscanChat(forAddress: account.address)
    }

    func walletConnectSelected(in controller: SettingsViewController) {
        walletConnectCoordinator.showSessions()
    }

    func showSeedPhraseSelected(in controller: SettingsViewController) {
        guard case .real(let account) = account.type else { return }

        let coordinator = ShowSeedPhraseCoordinator(
            navigationController: navigationController,
            keystore: keystore,
            account: account)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func helpSelected(in controller: SettingsViewController) {
        let coordinator = SupportCoordinator(navigationController: navigationController, analytics: analytics)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    func changeWalletSelected(in controller: SettingsViewController) {
        let coordinator = AccountsCoordinator(
            config: config,
            navigationController: navigationController,
            keystore: keystore,
            analytics: analytics,
            viewModel: .init(configuration: .changeWallets, animatedPresentation: true),
            walletBalanceService: walletBalanceService,
            blockiesGenerator: blockiesGenerator,
            domainResolutionService: domainResolutionService,
            promptBackup: promptBackup)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func myWalletAddressSelected(in controller: SettingsViewController) {
        delegate?.didPressShowWallet(in: self)
    }

    func backupWalletSelected(in controller: SettingsViewController) {
        guard case .real = account.type else { return }

        let coordinator = BackupCoordinator(
            navigationController: navigationController,
            keystore: keystore,
            account: account,
            analytics: analytics,
            promptBackup: promptBackup)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func activeNetworksSelected(in controller: SettingsViewController) {
        let coordinator = EnabledServersCoordinator(
            navigationController: navigationController,
            selectedServers: serversProvider.enabledServers,
            restartHandler: restartHandler,
            analytics: analytics,
            config: config,
            networkService: networkService,
            serversProvider: serversProvider)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func advancedSettingsSelected(in controller: SettingsViewController) {
        let viewModel = AdvancedSettingsViewModel(wallet: account, config: config)
        let controller = AdvancedSettingsViewController(viewModel: viewModel)
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }
}

extension SettingsCoordinator: ShowSeedPhraseCoordinatorDelegate {
    func didCancel(in coordinator: ShowSeedPhraseCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: SupportCoordinatorDelegate {
    func didClose(in coordinator: SupportCoordinator) {
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

    func didClose(in coordinator: EnabledServersCoordinator) {
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
    func didCancel(in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }

    func didFinish(account: AlphaWallet.Address, in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: AdvancedSettingsViewControllerDelegate {
    func moreSelected(in controller: AdvancedSettingsViewController) {
        let viewModel = ToolsViewModel(config: config)
        let viewController = ToolsViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true
        viewController.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(viewController, animated: true)
    }

    func clearBrowserCacheSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = ClearDappBrowserCacheCoordinator(viewController: rootViewController, analytics: analytics)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func tokenScriptSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = AssetDefinitionStoreCoordinator(tokenScriptOverridesFileManager: tokenScriptOverridesFileManager, navigationController: navigationController)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    func changeLanguageSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = LocalesCoordinator()
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
        coordinator.localesViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(coordinator.localesViewController, animated: true)
    }

    func changeCurrencySelected(in controller: AdvancedSettingsViewController) {
        let coordinator = ChangeCurrencyCoordinator(navigationController: navigationController, currencyService: currencyService)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func analyticsSelected(in controller: AdvancedSettingsViewController) {
        let viewModel = AnalyticsViewModel(config: config)
        let controller = AnalyticsViewController(viewModel: viewModel)
        navigationController.pushViewController(controller, animated: true)
    }

    func crashReporterSelected(in controller: AdvancedSettingsViewController) {
        let viewModel = CrashReporterViewModel(config: config)
        let controller = CrashReporterViewController(viewModel: viewModel)
        navigationController.pushViewController(controller, animated: true)
    }

    func usePrivateNetworkSelected(in controller: AdvancedSettingsViewController) {
        let viewModel = ChooseSendPrivateTransactionsProviderViewModel(config: config)
        let controller = ChooseSendPrivateTransactionsProviderViewController(viewModel: viewModel)
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    func exportJSONKeystoreSelected(in controller: AdvancedSettingsViewController) {
        let coordinator = ExportJsonKeystoreCoordinator(keystore: keystore, wallet: account, navigationController: navigationController)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func featuresSelected(in controller: AdvancedSettingsViewController) {
        let controller = FeaturesViewController()
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }

}

extension SettingsCoordinator: ChangeCurrencyCoordinatorDelegate {
    func didChangeCurrency(in coordinator: ChangeCurrencyCoordinator, currency: AlphaWalletFoundation.Currency) {
        removeCoordinator(coordinator)
        restart(for: account, reason: .currencyChange)
    }

    func didClose(in coordinator: ChangeCurrencyCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SettingsCoordinator: AssetDefinitionStoreCoordinatorDelegate {
    func didClose(in coordinator: AssetDefinitionStoreCoordinator) {
        removeCoordinator(coordinator)
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
    func didCancel(in coordinator: ExportJsonKeystoreCoordinator) {
        removeCoordinator(coordinator)
    }

    func didComplete(in coordinator: ExportJsonKeystoreCoordinator) {
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
    func checkTransactionStateSelected(in controller: ToolsViewController) {
        let coordinator = CheckTransactionStateCoordinator(navigationController: navigationController, config: config, sessionsProvider: sessionsProvider)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func consoleSelected(in controller: ToolsViewController) {
        delegate?.showConsole(in: self)
    }

    func pingInfuraSelected(in controller: ToolsViewController) {
        let coordinator = PingInfuraCoordinator(viewController: controller, analytics: analytics, sessionsProvider: sessionsProvider)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}
