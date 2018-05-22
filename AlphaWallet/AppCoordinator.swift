// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit
import BigInt

class AppCoordinator: NSObject, Coordinator {
    let navigationController: UINavigationController
    lazy var welcomeViewController: WelcomeViewController = {
        let controller = WelcomeViewController()
        controller.delegate = self
        return controller
    }()
    private let lock = Lock()
    private var keystore: Keystore
    private var appTracker = AppTracker()
    var coordinators: [Coordinator] = []
    var inCoordinator: InCoordinator? {
        return coordinators.first { $0 is InCoordinator } as? InCoordinator
    }
    var ethPrice: Subscribable<Double>? {
        if let inCoordinator = inCoordinator {
            return inCoordinator.ethPrice
        } else {
            return nil
        }
    }
    var ethBalance: Subscribable<BigInt>? {
        if let inCoordinator = inCoordinator {
            return inCoordinator.ethBalance
        } else {
            return nil
        }
    }
    init(
        window: UIWindow,
        keystore: Keystore,
        navigationController: UINavigationController = NavigationController()
    ) {
        self.navigationController = navigationController
        self.keystore = keystore
        super.init()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }

    func start() {
        inializers()
        appTracker.start()
        handleNotifications()
        applyStyle()
        resetToWelcomeScreen()

        if keystore.hasWallets {
            showTransactions(for: keystore.recentlyUsedWallet ?? keystore.wallets.first!)
        } else {
            resetToWelcomeScreen()
        }
    }

    func showTransactions(for wallet: Wallet) {
        let coordinator = InCoordinator(
            navigationController: navigationController,
            wallet: wallet,
            keystore: keystore,
            appTracker: appTracker
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func inializers() {
        var paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).flatMap { URL(fileURLWithPath: $0) }
        paths.append(keystore.keystoreDirectory)

        let initializers: [Initializer] = [
            LokaliseInitializer(),
            SkipBackupFilesInitializer(paths: paths),
        ]
        initializers.forEach { $0.perform() }
        //We should clean passcode if there is no wallets. This step is required for app reinstall.
        if !keystore.hasWallets {
           lock.clear()
        }
    }

    func handleNotifications() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func resetToWelcomeScreen() {
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.viewControllers = [welcomeViewController]
    }

    @objc func reset() {
        lock.deletePasscode()
        coordinators.removeAll()
        navigationController.dismiss(animated: true, completion: nil)
        resetToWelcomeScreen()
    }

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void) {
        let inCoordinatorInstance = coordinators.first {
            $0 is InCoordinator
        } as? InCoordinator
        
        if let inCoordinator = inCoordinatorInstance {
            inCoordinator.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject, completion: completion)
        }
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
}
