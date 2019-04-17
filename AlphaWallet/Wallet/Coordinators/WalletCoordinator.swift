// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
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
        case .createInstantWallet:
            createInstantWallet()
            return false
        case .backupWallet(let address):
            if let type = keystore.recentlyUsedWallet?.type, case let .real(account) = type {
                guard address.sameContract(as: account.address.eip55String) else { return false }
                guard !config.isWalletAddressAlreadyPromptedForBackUp(address: account.address.eip55String) else { return false }
                config.addToWalletAddressesAlreadyPromptedForBackup(address: account.address.eip55String)
                pushBackup(for: account)
            } else {
                return false
            }
        }
        return true
    }

    func pushImportWallet() {
        let controller = ImportWalletViewController(keystore: keystore)
        controller.delegate = self
        navigationController.pushViewController(controller, animated: true)
    }
    
    func createInitialWallet() {
        if !keystore.hasWallets {
            completeInstantWallet(password: PasswordGenerator.generateRandom(), initial: true)
        }
    }

    func createInstantWallet() {
        navigationController.displayLoading(text: R.string.localizable.walletCreateInProgress(), animated: false)
        completeInstantWallet(password: PasswordGenerator.generateRandom(), initial: false)
    }

    //since creating an ICAP key will require about 256 tries, we should only have to make the password once
    private func completeInstantWallet(password: String, initial: Bool) {
        keystore.createAccount(with: password) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let account):
                //Ensure that an ICAP compatible address is always generated
                //See https://ethereum.stackexchange.com/questions/1085/what-is-an-icap-address
                if account.address.data.array[0] == UInt8(0x00) {
                    let wallet = Wallet(type: WalletType.real(account))
                    strongSelf.delegate?.didFinish(with: wallet, in: strongSelf)
                    if initial {
                        strongSelf.keystore.recentlyUsedWallet = Wallet(type: WalletType.real(account))
                    }
                } else {
                    return strongSelf.completeInstantWallet(password: password, initial: initial)
                }
            case .failure(let error):
                //TODO this wouldn't work since navigationController isn't shown anymore
                strongSelf.navigationController.displayError(error: error)
            }
            strongSelf.navigationController.hideLoading(animated: false)
        }
    }

    func pushBackup(for account: Account) {
        let controller = BackupViewController(account: account)
        controller.delegate = self
        controller.navigationItem.backBarButtonItem = nil
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: self, action: nil)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.pushViewController(controller, animated: true)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }

    func didCreateAccount(account: Wallet) {
        delegate?.didFinish(with: account, in: self)
    }

    func backup(account: Account) {
        let coordinator = BackupCoordinator(
            navigationController: navigationController,
            keystore: keystore,
            account: account
        )
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
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
    func didPressCreateWallet(in viewController: WelcomeViewController) {
//        showInitialWalletCoordinator(entryPoint: .createInstantWallet)
    }
}

extension WalletCoordinator: ImportWalletViewControllerDelegate {
    func didImportAccount(account: Wallet, in viewController: ImportWalletViewController) {
        config.addToWalletAddressesAlreadyPromptedForBackup(address: account.address.eip55String)
        didCreateAccount(account: account)
    }
}

extension WalletCoordinator: BackupViewControllerDelegate {
    func didPressBackup(account: Account, in viewController: BackupViewController) {
        backup(account: account)
    }
}

extension WalletCoordinator: BackupCoordinatorDelegate {
    func didCancel(coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
    }

    func didFinish(account: Account, in coordinator: BackupCoordinator) {
        removeCoordinator(coordinator)
        didCreateAccount(account: Wallet(type: .real(account)))
    }
}
