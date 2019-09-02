// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import LocalAuthentication
import UIKit

protocol BackupSeedPhraseCoordinatorDelegate: class {
    func didClose(forAccount account: EthereumAccount, inCoordinator coordinator: BackupSeedPhraseCoordinator)
    func didVerifySeedPhraseSuccessfully(forAccount account: EthereumAccount, inCoordinator coordinator: BackupSeedPhraseCoordinator)
}

class BackupSeedPhraseCoordinator: Coordinator {
    private lazy var rootViewController: SeedPhraseBackupIntroductionViewController = {
        let controller = SeedPhraseBackupIntroductionViewController(account: account)
        controller.delegate = self
        controller.configure()
        return controller
    }()
    private lazy var showSeedPhraseViewController: ShowSeedPhraseViewController = {
        return createShowSeedPhraseViewController()
    }()
    private lazy var verifySeedPhraseViewController: VerifySeedPhraseViewController = {
        return createVerifySeedPhraseViewController()
    }()
    private let account: EthereumAccount
    private let keystore: Keystore
    private var _context: LAContext?
    private var context: LAContext {
        if let context = _context {
            return context
        } else {
            //TODO: This assumes we only access `context` when we going to use it immediately (and hence access biometrics). Can we make this more explicit?
            _isInactiveBecauseWeAccessingBiometrics = true
            let context = LAContext()
            _context = context
            return context
        }
    }
    //We have this flag because when prompted for Touch ID/Face ID, the app becomes inactive, and the order is:
    //1. we read the seed, thus the prompt shows up, making the app inactive
    //2. user authenticates and we get the seed
    //3. app is now notified as inactive! (note that this is after authentication succeeds)
    //4. app becomes active
    //Without this flag, we will be removing the seed in (3) and trying to read it in (4) again and triggering (1), thus going into an infinite loop of reading
    private var _isInactiveBecauseWeAccessingBiometrics = false

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: BackupSeedPhraseCoordinatorDelegate?

    init(navigationController: UINavigationController = UINavigationController(), keystore: Keystore, account: EthereumAccount) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignsActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    func start() {
        navigationController.pushViewController(rootViewController, animated: true)
    }

    func end() {
        showSeedPhraseViewController.markDone()
    }

    private func createShowSeedPhraseViewController() -> ShowSeedPhraseViewController {
        let controller = ShowSeedPhraseViewController(keystore: keystore, account: account)
        controller.configure()
        controller.delegate = self
        return controller
    }

    private func createVerifySeedPhraseViewController() -> VerifySeedPhraseViewController {
        let controller = VerifySeedPhraseViewController(keystore: keystore, account: account)
        controller.configure()
        controller.delegate = self
        return controller
    }

    //We need to call this after biometrics is cancelled so that when biometrics is accessed again (because it was cancelled, so it needs to be accessed again), we track background state correctly
    private func clearContext() {
        _context = nil
    }

    @objc private func appWillResignsActive() {
        if _isInactiveBecauseWeAccessingBiometrics {
            _isInactiveBecauseWeAccessingBiometrics = false
            return
        }
        _context = nil
        showSeedPhraseViewController.removeSeedPhraseFromDisplay()
        verifySeedPhraseViewController.removeSeedPhraseFromDisplay()
    }

    func endUserInterface(animated: Bool) {
        let _ = navigationController.viewControllers.firstIndex(of: rootViewController)
                .flatMap { navigationController.viewControllers[$0 - 1] }
                .flatMap { navigationController.popToViewController($0, animated: animated) }
    }
}

extension BackupSeedPhraseCoordinator: ShowSeedPhraseViewControllerDelegate {
    var isInactiveBecauseWeAccessingBiometrics: Bool {
        get {
            return _isInactiveBecauseWeAccessingBiometrics
        }
        set {
            _isInactiveBecauseWeAccessingBiometrics = newValue
        }
    }

    var contextToShowSeedPhrase: LAContext {
        return context
    }

    func didTapTestSeedPhrase(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController) {
        //Important to re-create it because we want to make sure the seed phrase display state etc are correct
        verifySeedPhraseViewController = createVerifySeedPhraseViewController()
        navigationController.pushViewController(verifySeedPhraseViewController, animated: true)
    }

    func biometricsFailed(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController) {
        clearContext()
    }
}

extension BackupSeedPhraseCoordinator: SeedPhraseBackupIntroductionViewControllerDelegate {
    func didTapBackupWallet(inViewController viewController: SeedPhraseBackupIntroductionViewController) {
        //Important to re-create it because we want to make sure the seed phrase display state etc are correct
        showSeedPhraseViewController = createShowSeedPhraseViewController()
        navigationController.pushViewController(showSeedPhraseViewController, animated: true)
    }

    func didClose(for account: EthereumAccount, inViewController viewController: SeedPhraseBackupIntroductionViewController) {
        delegate?.didClose(forAccount: account, inCoordinator: self)
    }
}

extension BackupSeedPhraseCoordinator: VerifySeedPhraseViewControllerDelegate {
    var contextToVerifySeedPhrase: LAContext {
        return context
    }

    func didVerifySeedPhraseSuccessfully(for account: EthereumAccount, in viewController: VerifySeedPhraseViewController) {
        delegate?.didVerifySeedPhraseSuccessfully(forAccount: account, inCoordinator: self)
    }

    func biometricsFailed(for account: EthereumAccount, inViewController viewController: VerifySeedPhraseViewController) {
        clearContext()
    }
}
