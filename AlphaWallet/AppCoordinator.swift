// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit
import BigInt

class AppCoordinator: NSObject, Coordinator {
    private let config: Config
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
    private var ethPrice: Subscribable<Double>? {
        if let inCoordinator = inCoordinator {
            return inCoordinator.ethPrice
        } else {
            return nil
        }
    }
    private var ethBalance: Subscribable<BigInt>? {
        if let inCoordinator = inCoordinator {
            return inCoordinator.ethBalance
        } else {
            return nil
        }
    }

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    var inCoordinator: InCoordinator? {
        return coordinators.first { $0 is InCoordinator } as? InCoordinator
    }

    init(
        config: Config = Config(),
        window: UIWindow,
        keystore: Keystore,
        navigationController: UINavigationController = NavigationController()
    ) {
        self.config = config
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
        setupAssetDefinitionStore()

        if keystore.hasWallets {
            showTransactions(for: keystore.recentlyUsedWallet ?? keystore.wallets.first!)
        } else {
            resetToWelcomeScreen()
        }
    }

    /// Return true if handled
    func handleOpen(url: URL) -> Bool {
        if let assetDefinitionStoreCoordinator = assetDefinitionStoreCoordinator {
            return assetDefinitionStoreCoordinator.handleOpen(url: url)
        } else {
            return false
        }
    }

    private func setupAssetDefinitionStore() {
        let coordinator = AssetDefinitionStoreCoordinator()
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showTransactions(for wallet: Wallet) {
        let coordinator = InCoordinator(
                navigationController: navigationController,
                wallet: wallet,
                keystore: keystore,
                assetDefinitionStore: assetDefinitionStore,
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
        paths.append(keystore.keystoreDirectory)

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
                navigationController: navigationController,
                keystore: keystore,
                entryPoint: entryPoint
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func createInitialWallet() {
        WalletCoordinator(keystore: keystore).createInitialWallet()
    }

    func handleUniversalLink(url: URL) -> Bool {
        createInitialWallet()
        closeWelcomeWindow()
        guard let ethPrice = self.ethPrice, let ethBalance = self.ethBalance else { return false }
        guard let inCoordinator = self.inCoordinator, let tokensDatastore = inCoordinator.createTokensDatastore() else { return false }

        let universalLinkCoordinator = UniversalLinkCoordinator(
                config: config,
                ethPrice: ethPrice,
                ethBalance: ethBalance,
                tokensDatastore: tokensDatastore,
                assetDefinitionStore: assetDefinitionStore
        )
        universalLinkCoordinator.delegate = self
        universalLinkCoordinator.start()
        let handled = universalLinkCoordinator.handleUniversalLink(url: url)
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

    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        inCoordinator?.didPressViewContractWebPage(forContract: contract, in: viewController)
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
    func didPressCreateWallet(in viewController: WelcomeViewController) {
        showInitialWalletCoordinator(entryPoint: .createInstantWallet)
    }
}

extension AppCoordinator: InitialWalletCreationCoordinatorDelegate {
    func didCancel(in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
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
    }

    func didShowWallet(in coordinator: InCoordinator) {
        pushNotificationsCoordinator?.didShowWallet(in: coordinator.navigationController)
    }

    func assetDefinitionsOverrideViewController(for coordinator: InCoordinator) -> UIViewController? {
        return assetDefinitionStoreCoordinator?.createOverridesViewController()
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

    func didImported(contract: String, in coordinator: UniversalLinkCoordinator) {
        inCoordinator?.addImported(contract: contract)
    }
}

extension AppCoordinator: UniversalLinkInPasteboardCoordinatorDelegate {
    func importUniversalLink(url: URL, for coordinator: UniversalLinkInPasteboardCoordinator) {
        guard universalLinkCoordinator == nil else { return }
        handleUniversalLink(url: url)
    }
}
