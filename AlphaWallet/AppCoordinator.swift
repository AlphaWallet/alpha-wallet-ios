// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class AppCoordinator: NSObject, Coordinator {
    private let config = Config()
    private lazy var welcomeViewController: WelcomeViewController = {
        let controller = WelcomeViewController()
        controller.delegate = self
        return controller
    }()
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

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var inCoordinator: InCoordinator? {
        return coordinators.first { $0 is InCoordinator } as? InCoordinator
    }

    init(
        window: UIWindow,
        keystore: Keystore,
        navigationController: UINavigationController = NavigationController()
    ) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.window = window
        super.init()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }

    func start() {
        initializers()
        appTracker.start()
        handleNotifications()
        applyStyle()
        resetToWelcomeScreen()
        setupAssetDefinitionStoreCoordinator()
        migrateToStoringRawPrivateKeysInKeychain()

        if keystore.hasWallets {
            showTransactions(for: keystore.recentlyUsedWallet ?? keystore.wallets.first!)
        } else {
            resetToWelcomeScreen()
        }

        assetDefinitionStore.delegate = self
    }

    private func migrateToStoringRawPrivateKeysInKeychain() {
        (try? LegacyFileBasedKeystore())?.migrateKeystoreFilesToRawPrivateKeysInKeychain()
    }

    /// Return true if handled
    func handleOpen(url: URL) -> Bool {
        if let assetDefinitionStoreCoordinator = assetDefinitionStoreCoordinator {
            let handled = assetDefinitionStoreCoordinator.handleOpen(url: url)
            if handled {
                return true
            }
        }
        guard let inCoordinator = inCoordinator else { return false }
        let urlSchemeHandler = CustomUrlSchemeCoordinator(tokensDatastores: inCoordinator.tokensStorages)
        urlSchemeHandler.delegate = self
        return urlSchemeHandler.handleOpen(url: url)
    }

    private func setupAssetDefinitionStoreCoordinator() {
        let coordinator = AssetDefinitionStoreCoordinator(assetDefinitionStore: assetDefinitionStore)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showTransactions(for wallet: Wallet) {
        let coordinator = InCoordinator(
                navigationController: navigationController,
                wallet: wallet,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
                config: config,
                appTracker: appTracker
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func closeWelcomeWindow() {
        guard navigationController.viewControllers.contains(welcomeViewController) else {
            return
        }
        navigationController.dismiss(animated: true, completion: nil)
        if let wallet = keystore.recentlyUsedWallet {
            showTransactions(for: wallet)
        }
    }

    private func initializers() {
        var paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        paths.append((try! LegacyFileBasedKeystore()).keystoreDirectory)

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

    private func resetToWelcomeScreen() {
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.viewControllers = [welcomeViewController]
    }

    @objc func reset() {
        lock.deletePasscode()
        coordinators.removeAll()
        navigationController.dismiss(animated: true, completion: nil)
        resetToWelcomeScreen()
    }

    func showInitialWalletCoordinator(entryPoint: WalletEntryPoint) {
        let coordinator = InitialWalletCreationCoordinator(
                config: config,
                navigationController: navigationController,
                keystore: keystore,
                entryPoint: entryPoint
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func createInitialWalletIfMissing() {
        WalletCoordinator(config: config, keystore: keystore).createInitialWalletIfMissing()
    }

    @discardableResult func handleUniversalLink(url: URL) -> Bool {
        createInitialWalletIfMissing()
        closeWelcomeWindow()
        //TODO refactor. Some of these should be moved into InCoordinator instead of reaching into its internals
        guard let inCoordinator = self.inCoordinator else { return false }
        let prices = inCoordinator.nativeCryptoCurrencyPrices
        let balances = inCoordinator.nativeCryptoCurrencyBalances
        guard let universalLinkCoordinator = UniversalLinkCoordinator(
                config: config,
                ethPrices: prices,
                ethBalances: balances,
                tokensDatastores: inCoordinator.tokensStorages,
                assetDefinitionStore: assetDefinitionStore,
                url: url
        ) else { return false }
        universalLinkCoordinator.delegate = self
        universalLinkCoordinator.start()
        let handled = universalLinkCoordinator.handleUniversalLink()
        if handled {
            addCoordinator(universalLinkCoordinator)
        }
        return handled
    }

    func handleUniversalLinkInPasteboard() {
        let universalLinkPasteboardCoordinator = UniversalLinkInPasteboardCoordinator()
        universalLinkPasteboardCoordinator.delegate = self
        universalLinkPasteboardCoordinator.start()
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

//Disable creating and importing wallets from welcome screen
//extension AppCoordinator: WelcomeViewControllerDelegate {
//    func didPressCreateWallet(in viewController: WelcomeViewController) {
//        showInitialWalletCoordinator(entryPoint: .createInstantWallet)
//    }

//    func didPressImportWallet(in viewController: WelcomeViewController) {
//        showInitialWalletCoordinator(entryPoint: .importWallet)
//    }
//}

extension AppCoordinator: WelcomeViewControllerDelegate {
    func didPressGettingStartedButton(in viewController: WelcomeViewController) {
        showInitialWalletCoordinator(entryPoint: .addInitialWallet)
    }
}

extension AppCoordinator: InitialWalletCreationCoordinatorDelegate {
    func didCancel(in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator) {
        navigationController.dismiss(animated: true, completion: nil)
        self.removeCoordinator(coordinator)
        self.showTransactions(for: account)
    }
}

extension AppCoordinator: InCoordinatorDelegate {
    func didCancel(in coordinator: InCoordinator) {
        removeCoordinator(coordinator)
        reset()
    }

    func didUpdateAccounts(in coordinator: InCoordinator) {
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

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void) {
        inCoordinator?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject, completion: completion)
    }

    func completed(in coordinator: UniversalLinkCoordinator) {
        removeCoordinator(coordinator)
    }

    func didImported(contract: AlphaWallet.Address, in coordinator: UniversalLinkCoordinator) {
        inCoordinator?.addImported(contract: contract, forServer: coordinator.server)
    }
}

extension AppCoordinator: UniversalLinkInPasteboardCoordinatorDelegate {
    func importUniversalLink(url: URL, for coordinator: UniversalLinkInPasteboardCoordinator) {
        guard universalLinkCoordinator == nil else { return }
        handleUniversalLink(url: url)
    }
}

extension AppCoordinator: CustomUrlSchemeCoordinatorDelegate {
    func openSendPaymentFlow(_ paymentFlow: PaymentFlow, server: RPCServer, inCoordinator coordinator: CustomUrlSchemeCoordinator) {
        inCoordinator?.showPaymentFlow(for: paymentFlow, server: server)
    }
}

extension AppCoordinator: AssetDefinitionStoreCoordinatorDelegate {
    func show(error: Error, for viewController: AssetDefinitionStoreCoordinator) {
        inCoordinator?.show(error: error)
    }

    func addedTokenScript(forContract contract: AlphaWallet.Address, forServer server: RPCServer) {
        inCoordinator?.addImported(contract: contract, forServer: server)
    }
}

extension AppCoordinator: AssetDefinitionStoreDelegate {
    func listOfBadTokenScriptFilesChanged(in: AssetDefinitionStore ) {
        inCoordinator?.listOfBadTokenScriptFilesChanged(fileNames: assetDefinitionStore.listOfBadTokenScriptFiles + assetDefinitionStore.listOfConflictingTokenScriptFiles)
    }
}
