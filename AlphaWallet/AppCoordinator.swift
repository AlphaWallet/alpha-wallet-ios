// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import UIKit
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletTrackAPICalls
import AlphaWalletNotifications

class AppCoordinator: NSObject, Coordinator, ApplicationNavigatable {
    private let navigationSubject = CurrentValueSubject<ApplicationNavigation, Never>(.onboarding)
    private let application: Application
    private var keystore: Keystore
    private let window: UIWindow
    private var initialWalletCreationCoordinator: InitialWalletCreationCoordinator? {
        return coordinators.compactMap { $0 as? InitialWalletCreationCoordinator }.first
    }

    private var importMagicLinkCoordinator: ImportMagicLinkCoordinator? {
        return coordinators.compactMap { $0 as? ImportMagicLinkCoordinator }.first
    }

    private lazy var protectionCoordinator: ProtectionCoordinator = {
        return ProtectionCoordinator(lock: application.lock)
    }()

    private var latestActiveWalletCoordinator: ActiveWalletCoordinator?

    private lazy var accountsCoordinator: AccountsCoordinator = {
        let coordinator = AccountsCoordinator(
            config: application.config,
            navigationController: navigationController,
            keystore: keystore,
            analytics: application.analytics,
            viewModel: .init(configuration: .summary),
            walletBalanceService: application.walletBalanceService,
            blockiesGenerator: application.blockiesGenerator,
            domainResolutionService: application.domainResolutionService,
            promptBackup: application.promptBackup)

        coordinator.delegate = self

        return coordinator
    }()

    private lazy var walletConnectCoordinator: WalletConnectCoordinator = {
        let coordinator = WalletConnectCoordinator(
            navigationController: navigationController,
            analytics: application.analytics,
            walletConnectProvider: application.walletConnectProvider,
            restartHandler: application.restartHandler,
            serversProvider: application.serversProvider)

        return coordinator
    }()

    private lazy var walletApiCoordinator: WalletApiCoordinator = {
        let coordinator = WalletApiCoordinator(keystore: keystore, navigationController: navigationController, analytics: application.analytics, restartHandler: application.restartHandler)
        return coordinator
    }()

    //Unfortunate to have to have a factory method and not be able to use an initializer (because we can't override `init()` to throw)
    static func create(application: Application) -> AppCoordinator {
        applyStyle()

        let window = UIWindow(frame: UIScreen.main.bounds)
        let navigationController: UINavigationController = .withOverridenBarAppearence()
        navigationController.view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        let coordinator = AppCoordinator(
            window: window,
            navigationController: navigationController,
            application: application)

        return coordinator
    }

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var activeWalletCoordinator: ActiveWalletCoordinator? {
        return coordinators.compactMap { $0 as? ActiveWalletCoordinator }.first
    }

    var navigation: AnyPublisher<ApplicationNavigation, Never> {
        navigationSubject.eraseToAnyPublisher()
    }

    init(window: UIWindow,
         navigationController: UINavigationController,
         application: Application) {

        self.application = application
        self.navigationController = navigationController
        self.window = window
        self.keystore = application.keystore

        super.init()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        setupSplashViewController(on: navigationController)

        application.navigation = self
    }

    func showUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        activeWalletCoordinator?.showUniversalScanner(fromSource: source)
    }

    func showQrCode() {
        activeWalletCoordinator?.showWalletQrCode()
    }

    func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        protectionCoordinator.didFinishLaunchingWithOptions()
        application.start(launchOptions: launchOptions)

        walletApiCoordinator.delegate = application
        addCoordinator(walletApiCoordinator)
        addCoordinator(walletConnectCoordinator)
    }

    func applicationWillResignActive() {
        protectionCoordinator.applicationWillResignActive()
    }

    func applicationDidBecomeActive() {
        protectionCoordinator.applicationDidBecomeActive()
    }

    func applicationDidEnterBackground() {
        protectionCoordinator.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground() {
        protectionCoordinator.applicationWillEnterForeground()
    }

    private func setupSplashViewController(on navigationController: UINavigationController) {
        navigationController.viewControllers = [
            SplashViewController()
        ]
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    @discardableResult func showActiveWallet(for wallet: Wallet, animated: Bool) -> ActiveWalletCoordinator {
        if let coordinator = initialWalletCreationCoordinator {
            removeCoordinator(coordinator)
        }

        let dep = application.buildDependencies(for: wallet)

        let coordinator = ActiveWalletCoordinator(
            navigationController: navigationController,
            activitiesPipeLine: dep.activitiesPipeLine,
            wallet: wallet,
            keystore: keystore,
            assetDefinitionStore: application.assetDefinitionStore,
            config: application.config,
            appTracker: application.appTracker,
            analytics: application.analytics,
            restartHandler: application.restartHandler,
            universalLinkCoordinator: application.universalLinkService,
            accountsCoordinator: accountsCoordinator,
            walletBalanceService: application.walletBalanceService,
            coinTickersProvider: application.coinTickers,
            tokenActionsService: application.tokenActionsService,
            walletConnectCoordinator: walletConnectCoordinator,
            localNotificationsService: application.localNotificationsService,
            blockiesGenerator: application.blockiesGenerator,
            domainResolutionService: application.domainResolutionService,
            tokenSwapper: application.tokenSwapper,
            sessionsProvider: dep.sessionsProvider,
            tokenCollection: dep.pipeline,
            transactionsDataStore: dep.transactionsDataStore,
            tokensService: dep.tokensService,
            tokenGroupIdentifier: application.tokenGroupIdentifier,
            lock: application.lock,
            currencyService: application.currencyService,
            tokenScriptOverridesFileManager: application.tokenScriptOverridesFileManager,
            networkService: application.networkService,
            promptBackup: application.promptBackup,
            caip10AccountProvidable: application.caip10AccountProvidable,
            tokenImageFetcher: application.tokenImageFetcher,
            serversProvider: application.serversProvider,
            transactionsService: dep.transactionsService,
            pushNotificationsService: application.pushNotificationsService)

        coordinator.delegate = self

        addCoordinator(coordinator)
        addCoordinator(accountsCoordinator)

        coordinator.start(animated: animated)
        navigationSubject.send(.selectedWallet)

        return coordinator
    }

    @objc func reset() {
        application.lock.deletePasscode()
        coordinators.removeAll()
        navigationController.dismiss(animated: true)

        showCreateWallet()
    }

    func showActiveWallet(wallet: Wallet) {
        showActiveWallet(for: wallet, animated: false)
    }

    func showCreateWallet() {
        let coordinator = InitialWalletCreationCoordinator(
            config: application.config,
            navigationController: navigationController,
            keystore: keystore,
            analytics: application.analytics,
            domainResolutionService: application.domainResolutionService)

        coordinator.delegate = self
        coordinator.start()
        navigationSubject.send(.walletCreation)
        addCoordinator(coordinator)
    }

    func showActiveWalletIfNeeded() {
        guard let _ = showActiveWallet() else { return }
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        guard let coordinator = showActiveWallet() else { return }
        coordinator.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        guard let coordinator = showActiveWallet() else { return }
        coordinator.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        guard let coordinator = showActiveWallet() else { return }
        coordinator.didPressOpenWebPage(url, in: viewController)
    }

    func show(error: Error) {
        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        presenter.displayError(error: error)
    }

    func showTokenScriptFileImported(filename: String) {
        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        let controller = UIAlertController(
            title: nil,
            message: R.string.localizable.tokenscriptImportOk(filename),
            preferredStyle: .alert)

        controller.popoverPresentationController?.sourceView = presenter.view
        controller.addAction(.init(title: R.string.localizable.oK(), style: .default))

        presenter.present(controller, animated: true)
    }

    func openUrlInDappBrowser(url: URL, animated: Bool) {
        guard let coordinator = showActiveWallet() else { return }
        coordinator.openUrlInBrowser(url: url, animated: animated)
    }

    func openWalletConnectSession(url: AlphaWallet.WalletConnect.ConnectionUrl) {
        walletConnectCoordinator.openSession(url: url)
    }

    func showPaymentFlow(for type: PaymentFlow, server: RPCServer) {
        guard let coordinator = showActiveWallet() else { return }
        coordinator.showPaymentFlow(for: type, server: server)
    }

    func show(transaction: Transaction) {
        guard let coordinator = showActiveWallet() else { return }
        coordinator.show(transaction: transaction)
    }

}

extension AppCoordinator: InitialWalletCreationCoordinatorDelegate {

    func didCancel(in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didAddAccount(_ wallet: Wallet, in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)

        removeCoordinator(coordinator)
        showActiveWallet(for: wallet, animated: false)
    }

}

extension AppCoordinator: ActiveWalletCoordinatorDelegate {

    func didRestart(in coordinator: ActiveWalletCoordinator, reason: RestartReason, wallet: Wallet) {
        keystore.recentlyUsedWallet = wallet

        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)

        guard let wallet = keystore.currentWallet else { return }
        showActiveWallet(for: wallet, animated: false)
    }

    func showWallets(in coordinator: ActiveWalletCoordinator) {
        latestActiveWalletCoordinator = coordinator
        removeCoordinator(coordinator)

        coordinator.navigationController.popViewController(animated: true)
        coordinator.navigationController.setNavigationBarHidden(false, animated: false)

        navigationSubject.send(.walletList)
    }

    func didCancel(in coordinator: ActiveWalletCoordinator) {
        removeCoordinator(coordinator)
        reset()
    }

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: ActiveWalletCoordinator, source: UrlSource) {
        application.handleUniversalLink(url: url, source: source)
    }
}

extension AppCoordinator: ImportMagicLinkCoordinatorDelegate {

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        guard let coordinator = showActiveWallet() else { return }
        coordinator.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: source)
    }

    func viewControllerForPresenting(in coordinator: ImportMagicLinkCoordinator) -> UIViewController? {
        if var top = window.rootViewController {
            while let vc = top.presentedViewController {
                top = vc
            }
            return top
        } else {
            return nil
        }
    }

    func didClose(in coordinator: ImportMagicLinkCoordinator) {
        removeCoordinator(coordinator)
    }

    func showImportMagicLink(session: WalletSession, url: URL) {
        guard let dependency = application.walletDependencies(walletAddress: session.account.address), importMagicLinkCoordinator == nil else { return }

        let coordinator = ImportMagicLinkCoordinator(
            analytics: application.analytics,
            session: session,
            config: application.config,
            assetDefinitionStore: application.assetDefinitionStore,
            keystore: keystore,
            tokensService: dependency.pipeline,
            networkService: application.networkService,
            domainResolutionService: application.domainResolutionService,
            importToken: session.importToken,
            reachability: application.reachability)

        coordinator.delegate = self
        let handled = coordinator.start(url: url)

        if handled {
            addCoordinator(coordinator)
        }
    }

    func showServerUnavailable(server: RPCServer) {
        guard importMagicLinkCoordinator == nil else { return }

        let coordinator = ServerUnavailableCoordinator(
            navigationController: navigationController,
            disabledServers: [server],
            restartHandler: application.restartHandler)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showWalletApi(action: DeepLink.WalletApi) {
        walletApiCoordinator.handle(action: action)
    }
}

extension AppCoordinator: ServerUnavailableCoordinatorDelegate {
    func didDismiss(in coordinator: ServerUnavailableCoordinator, result: Swift.Result<Void, Error>) {
        removeCoordinator(coordinator)
        //TODO: update to retry operation again after enabling disabled servers
    }
}

extension AppCoordinator: SystemSettingsRequestable {
    func promptOpenSettings() async -> Result<Void, Error> {
        switch await UIApplication.shared.presentedViewController(or: navigationController).confirm(title: "Open settings") {
        case .success(let value):
            return .success(value)
        case .failure(let e):
            return .failure(e)
        }
    }
}

extension AppCoordinator: AccountsCoordinatorDelegate {

    func didAddAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
    }

    func didDeleteAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        guard keystore.wallets.isEmpty else { return }
        showCreateWallet()
    }

    func didCancel(in coordinator: AccountsCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
    }

    func didSelectAccount(account: Wallet, in coordinator: AccountsCoordinator) {
        //NOTE: Push existing view controller to the app navigation stack
        if let coordinator = latestActiveWalletCoordinator, keystore.currentWallet == account {
            show(activeWalletCoordinator: coordinator, animated: true)
        } else {
            showActiveWallet(for: account, animated: true)
        }

        latestActiveWalletCoordinator = .none
    }

    private func showActiveWallet(animated: Bool = false) -> ActiveWalletCoordinator? {
        if let coordinator = activeWalletCoordinator {
            return coordinator
        } else if let coordinator = latestActiveWalletCoordinator {
            show(activeWalletCoordinator: coordinator, animated: animated)

            return coordinator
        } else {
            return nil
        }
    }

    private func show(activeWalletCoordinator: ActiveWalletCoordinator, animated: Bool) {
        addCoordinator(activeWalletCoordinator)

        activeWalletCoordinator.showTabBar(animated: animated)
        navigationSubject.send(.selectedWallet)
        latestActiveWalletCoordinator = nil
    }
}
