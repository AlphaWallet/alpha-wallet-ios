// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol WalletCoordinatorDelegate: class {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator)
    func didCancel(in coordinator: WalletCoordinator)
}

class WalletCoordinator: Coordinator {
    private let config: Config
    private var entryPoint: WalletEntryPoint?
    private var keystore: Keystore

    var navigationController: UINavigationController
    weak var delegate: WalletCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(
        config: Config,
        navigationController: UINavigationController = NavigationController(),
        keystore: Keystore
    ) {
        self.config = config
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.keystore = keystore
        navigationController.navigationBar.isTranslucent = false
    }

    ///Return true if caller should proceed to show UI (`navigationController`)
    @discardableResult func start(_ entryPoint: WalletEntryPoint) -> Bool {
        self.entryPoint = entryPoint
        switch entryPoint {
        case .welcome:
            let controller = WelcomeViewController()
            controller.delegate = self
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            navigationController.viewControllers = [controller]
        case .importWallet:
            let controller = ImportWalletViewController(keystore: keystore)
            controller.delegate = self
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            navigationController.viewControllers = [controller]
        case .watchWallet:
            let controller = ImportWalletViewController(keystore: keystore)
            controller.delegate = self
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
            controller.showWatchTab()
            navigationController.viewControllers = [controller]
        case .createInstantWallet:
            createInstantWallet()
            return false
        case .addInitialWallet:
            let controller = CreateInitialWalletViewController(keystore: keystore)
            controller.delegate = self
            controller.configure()
            navigationController.viewControllers = [controller]
        }
        return true
    }

    func pushImportWallet() {
        let controller = ImportWalletViewController(keystore: keystore)
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(controller, animated: true)
    }

    func createInitialWalletIfMissing() {
        if !keystore.hasWallets {
            let result = keystore.createAccount()
            switch result {
            case .success(let account):
                keystore.recentlyUsedWallet = Wallet(type: WalletType.real(account))
            case .failure:
                //TODO handle initial wallet creation error. App can't be used!
                break
            }
        }
    }

    //TODO Rename this is create in both settings and new install
    func createInstantWallet() {
        navigationController.displayLoading(text: R.string.localizable.walletCreateInProgress(), animated: false)
        keystore.createAccount { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let account):
                let wallet = Wallet(type: WalletType.real(account))
                //Bit of delay to wait for the UI animation to almost finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    WhereIsWalletAddressFoundOverlayView.show()
                }
                strongSelf.delegate?.didFinish(with: wallet, in: strongSelf)
            case .failure(let error):
                //TODO this wouldn't work since navigationController isn't shown anymore
                strongSelf.navigationController.displayError(error: error)
            }
            strongSelf.navigationController.hideLoading(animated: false)
        }
    }

    private func addWalletWith(entryPoint: WalletEntryPoint) {
        //Intentionally creating an instance of myself
        let coordinator = WalletCoordinator(config: config, keystore: keystore)
        coordinator.delegate = self
        addCoordinator(coordinator)
        let _ = coordinator.start(entryPoint)
        coordinator.navigationController.makePresentationFullScreenForiOS13Migration()
        navigationController.present(coordinator.navigationController, animated: true, completion: nil)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }

    //TODO Rename this is import in both settings and new install
    func didCreateAccount(account: Wallet) {
        delegate?.didFinish(with: account, in: self)
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SuccessOverlayView.show()
        }
    }
}

//Disable creating and importing wallets from welcome screen
//extension WalletCoordinator: WelcomeViewControllerDelegate {
//    func didPressImportWallet(in viewController: WelcomeViewController) {
//        pushImportWallet()
//    }

//    func didPressCreateWallet(in viewController: WelcomeViewController) {
//        createInstantWallet()
//    }
//}

extension WalletCoordinator: WelcomeViewControllerDelegate {
    func didPressGettingStartedButton(in viewController: WelcomeViewController) {
//        showInitialWalletCoordinator(entryPoint: .createInstantWallet)
    }
}

extension WalletCoordinator: ImportWalletViewControllerDelegate {
    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController) {
        config.addToWalletAddressesAlreadyPromptedForBackup(address: account.address)
        didCreateAccount(account: account)
    }
}

extension WalletCoordinator: CreateInitialWalletViewControllerDelegate {
    func didTapCreateWallet(inViewController viewController: CreateInitialWalletViewController) {
        createInstantWallet()
    }

    func didTapWatchWallet(inViewController viewController: CreateInitialWalletViewController) {
        addWalletWith(entryPoint: .watchWallet)
    }

    func didTapImportWallet(inViewController viewController: CreateInitialWalletViewController) {
        addWalletWith(entryPoint: .importWallet)
    }
}

extension WalletCoordinator: WalletCoordinatorDelegate {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: false, completion: nil)
        self.removeCoordinator(coordinator)
        self.delegate?.didFinish(with: account, in: self)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        self.removeCoordinator(coordinator)
    }
}
