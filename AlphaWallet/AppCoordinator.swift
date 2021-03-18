// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class AppCoordinator: NSObject, Coordinator {
    private let config = Config()
    private let legacyFileBasedKeystore: LegacyFileBasedKeystore
    private let lock = Lock()
    private var keystore: Keystore
    private let assetDefinitionStore = AssetDefinitionStore()
    private let window: UIWindow
    private var appTracker = AppTracker()
    private var assetDefinitionStoreCoordinator: AssetDefinitionStoreCoordinator? {
        return coordinators.first { $0 is AssetDefinitionStoreCoordinator } as? AssetDefinitionStoreCoordinator
    }
    private var pushNotificationsCoordinator: PushNotificationsCoordinator? {
        return coordinators.first { $0 is PushNotificationsCoordinator } as? PushNotificationsCoordinator
    }
    private var universalLinkCoordinator: UniversalLinkCoordinator? {
        return coordinators.first { $0 is UniversalLinkCoordinator } as? UniversalLinkCoordinator
    }

    private var initialWalletCreationCoordinator: InitialWalletCreationCoordinator? {
        return coordinators.compactMap { $0 as? InitialWalletCreationCoordinator }.first
    }

    private lazy var urlSchemeCoordinator: UrlSchemeCoordinatorType = {
        let coordinator = UrlSchemeCoordinator()
        coordinator.delegate = self

        return coordinator
    }()

    private var analyticsService: AnalyticsServiceType
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var inCoordinator: InCoordinator? {
        return coordinators.first { $0 is InCoordinator } as? InCoordinator
    }

    init(window: UIWindow, analyticsService: AnalyticsServiceType, keystore: Keystore, navigationController: UINavigationController = UINavigationController()) throws {
        self.navigationController = navigationController
        self.window = window
        self.analyticsService = analyticsService
        self.keystore = keystore
        self.legacyFileBasedKeystore = try LegacyFileBasedKeystore(analyticsCoordinator: analyticsService)

        super.init()

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        setupSplashViewController(on: navigationController)
    }

    func start() {
        if isRunningTests() {
            startImpl()
        } else {
            DispatchQueue.main.async {
                let succeeded = self.startImpl()
                if succeeded {
                    return
                } else {
                    self.retryStart()
                }
            }
        }
    }

    private func setupSplashViewController(on navigationController: UINavigationController) {
        navigationController.viewControllers = [
            SplashViewController()
        ]
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    private func retryStart() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let succeeded = self.startImpl()
            if succeeded {
                return
            } else {
                self.retryStart()
            }
        }
    }

    //This function exist to handle what we think is a rare (but hard to reproduce) occurrence that NSUserDefaults are not accessible for a short while during startup. If that happens, we delay the "launch" and check again. If the app is killed by the iOS launch time watchdog, so be it. Better than to let the user create a wallet and wipe the list of wallets and lose access
    @discardableResult private func startImpl() -> Bool {
        if MigrationInitializer.hasRealmDatabasesForWallet && !keystore.hasWallets && !isRunningTests() {
            return false
        }

        MigrationInitializer.removeWalletsIfRealmFilesMissed(keystore: keystore)

        initializers()
        appTracker.start()
        handleNotifications()
        applyStyle()

        setupAssetDefinitionStoreCoordinator()
        migrateToStoringRawPrivateKeysInKeychain()

        if keystore.hasWallets {
            showTransactions(for: keystore.currentWallet)
        } else {
            showInitialWalletCoordinator()
        }

        assetDefinitionStore.delegate = self
        return true
    }

    private func migrateToStoringRawPrivateKeysInKeychain() {
        legacyFileBasedKeystore.migrateKeystoreFilesToRawPrivateKeysInKeychain()
    }

    /// Return true if handled
    @discardableResult func handleOpen(url: URL) -> Bool {
        let handled = urlSchemeCoordinator.handleOpen(url: url)
        if handled {
            return true
        }

        if let assetDefinitionStoreCoordinator = assetDefinitionStoreCoordinator {
            let handled = assetDefinitionStoreCoordinator.handleOpen(url: url)
            if handled {
                return true
            }
        }

        guard let inCoordinator = inCoordinator else { return false }
        let urlSchemeHandler = CustomUrlSchemeCoordinator(tokensDatastores: inCoordinator.tokensStorages, assetDefinitionStore: assetDefinitionStore)
        urlSchemeHandler.delegate = self
        return urlSchemeHandler.handleOpen(url: url)
    }

    private func setupAssetDefinitionStoreCoordinator() {
        let coordinator = AssetDefinitionStoreCoordinator(assetDefinitionStore: assetDefinitionStore)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    @discardableResult func showTransactions(for wallet: Wallet) -> InCoordinator {
        if let coordinator = initialWalletCreationCoordinator {
            removeCoordinator(coordinator)
        }

        let coordinator = InCoordinator(
                navigationController: navigationController,
                wallet: wallet,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
                config: config,
                appTracker: appTracker,
                analyticsCoordinator: analyticsService,
                urlSchemeCoordinator: urlSchemeCoordinator
        )

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)

        return coordinator
    }

    @discardableResult private func showTransactionsIfNeeded() -> InCoordinator {
        if let coordinator = inCoordinator {
            return coordinator
        } else {
            return showTransactions(for: keystore.currentWallet)
        }
    }

    private func initializers() {
        var paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        paths.append(legacyFileBasedKeystore.keystoreDirectory)

        let initializers: [Initializer] = [
            SkipBackupFilesInitializer(paths: paths),
        ]
        initializers.forEach { $0.perform() }
        //We should clean passcode if there is no wallets. This step is required for app reinstall.
        if !keystore.hasWallets {
            lock.clear()
        }
    }

    private func handleNotifications() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        let coordinator = PushNotificationsCoordinator()
        coordinator.start()
        addCoordinator(coordinator)
    }

    @objc func reset() {
        lock.deletePasscode()
        coordinators.removeAll()
        navigationController.dismiss(animated: true)

        showInitialWalletCoordinator()
    }

    func showInitialWalletCoordinator() {
        let coordinator = InitialWalletCreationCoordinator(config: config, navigationController: navigationController, keystore: keystore, analyticsCoordinator: analyticsService)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func createInitialWalletIfMissing() {
        WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsService).createInitialWalletIfMissing()
    }

    @discardableResult func handleUniversalLink(url: URL) -> Bool {
        createInitialWalletIfMissing()
        let inCoordinator = showTransactionsIfNeeded()

        guard let server = RPCServer(withMagicLink: url) else { return false }

        if config.enabledServers.contains(server) {
            let universalLinkCoordinator = UniversalLinkCoordinator(
                analyticsCoordinator: analyticsService,
                wallet: keystore.currentWallet,
                config: config,
                ethPrice: inCoordinator.nativeCryptoCurrencyPrices[server],
                ethBalance: inCoordinator.nativeCryptoCurrencyBalances[server],
                tokensDatastore: inCoordinator.tokensStorages[server],
                assetDefinitionStore: assetDefinitionStore,
                url: url,
                server: server
            )

            universalLinkCoordinator.delegate = self
            universalLinkCoordinator.start()

            let handled = universalLinkCoordinator.handleUniversalLink()
            if handled {
                addCoordinator(universalLinkCoordinator)
            }
            return handled
        } else {
            let coordinator = ServerUnavailableCoordinator(navigationController: navigationController, server: server, coordinator: self)
            coordinator.start().done { _ in
                //no-op
            }.cauterize()

            return false
        }
    }

    func handleUniversalLinkInPasteboard() {
        let universalLinkPasteboardCoordinator = UniversalLinkInPasteboardCoordinator()
        universalLinkPasteboardCoordinator.delegate = self
        universalLinkPasteboardCoordinator.start()
    }

    func launchUniversalScanner() {
        inCoordinator?.launchUniversalScanner()
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        inCoordinator?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        inCoordinator?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        inCoordinator?.didPressOpenWebPage(url, in: viewController)
    }
}

extension AppCoordinator: InitialWalletCreationCoordinatorDelegate {

    func didCancel(in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)
    }

    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true)

        removeCoordinator(coordinator)
        showTransactions(for: account)
    }
}

extension AppCoordinator: InCoordinatorDelegate {

    func didCancel(in coordinator: InCoordinator) {
        removeCoordinator(coordinator)
        reset()
    }

    func didUpdateAccounts(in coordinator: InCoordinator) {
        //no-op
    }

    func didShowWallet(in coordinator: InCoordinator) {
        pushNotificationsCoordinator?.didShowWallet(in: coordinator.navigationController)
    }

    func assetDefinitionsOverrideViewController(for coordinator: InCoordinator) -> UIViewController? {
        return assetDefinitionStoreCoordinator?.createOverridesViewController()
    }

    func importUniversalLink(url: URL, forCoordinator coordinator: InCoordinator) {
        guard universalLinkCoordinator == nil else { return }
        handleUniversalLink(url: url)
    }

    func handleUniversalLink(_ url: URL, forCoordinator coordinator: InCoordinator) {
        guard universalLinkCoordinator == nil else { return }
        handleUniversalLink(url: url)
    }

    func handleCustomUrlScheme(_ url: URL, forCoordinator coordinator: InCoordinator) {
        handleOpen(url: url)
    }
}

extension AppCoordinator: UniversalLinkCoordinatorDelegate {
    func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController? {
        if var top = window.rootViewController {
            while let vc = top.presentedViewController {
                top = vc
            }
            return top
        } else {
            return nil
        }
    }

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, inViewController viewController: ImportMagicTokenViewController, completion: @escaping (Bool) -> Void) {
        inCoordinator?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject, inViewController: viewController, completion: completion)
    }

    func completed(in coordinator: UniversalLinkCoordinator) {
        removeCoordinator(coordinator)
    }

    func didImported(contract: AlphaWallet.Address, in coordinator: UniversalLinkCoordinator) {
        inCoordinator?.addImported(contract: contract, forServer: coordinator.server)
    }

    func handle(walletConnectUrl url: WalletConnectURL) {
        inCoordinator?.openWalletConnectSession(url: url)
    }
}

extension AppCoordinator: UniversalLinkInPasteboardCoordinatorDelegate {
    func importUniversalLink(url: URL, for coordinator: UniversalLinkInPasteboardCoordinator) {
        guard universalLinkCoordinator == nil else { return }
        handleUniversalLink(url: url)
    }
}

extension AppCoordinator: CustomUrlSchemeCoordinatorResolver {
    func openSendPaymentFlow(_ paymentFlow: PaymentFlow, server: RPCServer, inCoordinator coordinator: CustomUrlSchemeCoordinator) {
        inCoordinator?.showPaymentFlow(for: paymentFlow, server: server)
    }
}

extension AppCoordinator: AssetDefinitionStoreCoordinatorDelegate {

    func show(error: Error, for viewController: AssetDefinitionStoreCoordinator) {
        inCoordinator?.show(error: error)
    }

    func addedTokenScript(forContract contract: AlphaWallet.Address, forServer server: RPCServer, destinationFileInUse: Bool, filename: String) {
        inCoordinator?.addImported(contract: contract, forServer: server)

        if !destinationFileInUse {
            inCoordinator?.show(openedURL: filename)
        }
    }
}

extension AppCoordinator: AssetDefinitionStoreDelegate {
    func listOfBadTokenScriptFilesChanged(in: AssetDefinitionStore ) {
        inCoordinator?.listOfBadTokenScriptFilesChanged(fileNames: assetDefinitionStore.listOfBadTokenScriptFiles + assetDefinitionStore.conflictingTokenScriptFileNames.all)
    }
}

extension AppCoordinator: UrlSchemeCoordinatorDelegate {
    func resolve(for coordinator: UrlSchemeCoordinator) -> UrlSchemeResolver? {
        return inCoordinator
    }
}
