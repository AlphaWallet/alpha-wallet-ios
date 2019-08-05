// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result

protocol BackupCoordinatorDelegate: class {
    func didCancel(coordinator: BackupCoordinator)
    func didFinish(account: EthereumAccount, in coordinator: BackupCoordinator)
}

class BackupCoordinator: Coordinator {
    private let keystore: Keystore
    private let account: EthereumAccount

    let navigationController: UINavigationController
    weak var delegate: BackupCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(navigationController: UINavigationController, keystore: Keystore, account: EthereumAccount) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
    }

    func start() {
        export(for: account)
    }

    private func finish(result: Result<Bool, AnyError>) {
        switch result {
        case .success:
            delegate?.didFinish(account: account, in: self)
        case .failure:
            delegate?.didCancel(coordinator: self)
        }
    }

    private func presentActivityViewController(for account: EthereumAccount, newPassword: String, completion: @escaping (Result<Bool, AnyError>) -> Void) {
        navigationController.displayLoading(
            text: R.string.localizable.exportPresentBackupOptionsLabelTitle()
        )
        keystore.exportRawPrivateKeyForNonHdWalletForBackup(forAccount: account, newPassword: newPassword) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.handleExport(result: result, completion: completion)
        }
    }

    private func handleExport(result: (Result<String, KeystoreError>), completion: @escaping (Result<Bool, AnyError>) -> Void) {
        switch result {
        case .success(let value):
            let url = URL(fileURLWithPath: NSTemporaryDirectory().appending("alphawallet_backup_\(account.address.eip55String).json"))
            do {
                try value.data(using: .utf8)!.write(to: url)
            } catch {
                return completion(.failure(AnyError(error)))
            }

            let activityViewController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            activityViewController.completionWithItemsHandler = { _, result, _, error in
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    //no-op
                }
                completion(.success(result))
            }
            activityViewController.popoverPresentationController?.sourceView = navigationController.view
            activityViewController.popoverPresentationController?.sourceRect = navigationController.view.centerRect
            navigationController.present(activityViewController, animated: true) { [weak self] in
                self?.navigationController.hideLoading()
            }
        case .failure(let error):
            navigationController.hideLoading()
            navigationController.displayError(error: error)
        }
    }

    private func presentShareActivity(for account: EthereumAccount, newPassword: String ) {
        presentActivityViewController(for: account, newPassword: newPassword) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let isBackedUp):
                if isBackedUp {
                    self?.promptElevateSecurityOrEnd()
                }
            case .failure:
                break
            }
        }
    }

    private func promptElevateSecurityOrEnd() {
        guard keystore.isUserPresenceCheckPossible else { return cleanUpAfterBackupAndNotPromptedToElevateSecurity() }
        guard !keystore.isProtectedByUserPresence(account: account) else { return cleanUpAfterBackupAndNotPromptedToElevateSecurity() }

        let coordinator = ElevateWalletSecurityCoordinator(navigationController: navigationController, keystore: keystore, account: account)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func export(for account: EthereumAccount) {
        if keystore.isHdWallet(account: account) {
            let coordinator = BackupSeedPhraseCoordinator(navigationController: navigationController, keystore: keystore, account: account)
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        } else {
            let coordinator = EnterPasswordCoordinator(navigationController: navigationController, account: account)
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        }
    }

    private func cleanUpAfterBackupAndPromptedToElevateSecurity() {
        let backupSeedPhraseCoordinator = coordinators.first { $0 is BackupSeedPhraseCoordinator } as? BackupSeedPhraseCoordinator
        defer { backupSeedPhraseCoordinator.flatMap { removeCoordinator($0) } }
        let elevateWalletSecurityCoordinator = coordinators.first { $0 is ElevateWalletSecurityCoordinator } as? ElevateWalletSecurityCoordinator
        defer { elevateWalletSecurityCoordinator.flatMap { removeCoordinator($0) } }
        let verifySeedPhraseCoordinator = coordinators.first { $0 is VerifySeedPhraseCoordinator } as? VerifySeedPhraseCoordinator
        defer { verifySeedPhraseCoordinator.flatMap { removeCoordinator($0) } }
        let enterPasswordCoordinator = coordinators.first { $0 is EnterPasswordCoordinator } as? EnterPasswordCoordinator
        defer { enterPasswordCoordinator.flatMap { removeCoordinator($0) } }

        enterPasswordCoordinator?.end()
        backupSeedPhraseCoordinator?.end()
        verifySeedPhraseCoordinator?.end()
        elevateWalletSecurityCoordinator?.end()

        //Must only call endUserInterface() on the coordinators managing the bottom-most view controller
        //Only one of these 2 coordinators will be nil
        backupSeedPhraseCoordinator?.endUserInterface(animated: true)
        enterPasswordCoordinator?.endUserInterface(animated: true)

        finish(result: .success(true))
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            SuccessOverlayView.show()
        }
    }

    private func cleanUpAfterBackupAndNotPromptedToElevateSecurity() {
        let backupSeedPhraseCoordinator = coordinators.first { $0 is BackupSeedPhraseCoordinator } as? BackupSeedPhraseCoordinator
        defer { backupSeedPhraseCoordinator.flatMap { removeCoordinator($0) } }
        let verifySeedPhraseCoordinator = coordinators.first { $0 is VerifySeedPhraseCoordinator } as? VerifySeedPhraseCoordinator
        defer { verifySeedPhraseCoordinator.flatMap { removeCoordinator($0) } }
        let enterPasswordCoordinator = coordinators.first { $0 is EnterPasswordCoordinator } as? EnterPasswordCoordinator
        defer { enterPasswordCoordinator.flatMap { removeCoordinator($0) } }

        enterPasswordCoordinator?.end()
        backupSeedPhraseCoordinator?.end()
        verifySeedPhraseCoordinator?.end()

        //Must only call endUserInterface() on the coordinators managing the bottom-most view controller
        //Only one of these 2 coordinators will be nil
        backupSeedPhraseCoordinator?.endUserInterface(animated: true)
        enterPasswordCoordinator?.endUserInterface(animated: true)

        finish(result: .success(true))
        //Bit of delay to wait for ttoree UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            SuccessOverlayView.show()
        }
    }
}

extension BackupCoordinator: EnterPasswordCoordinatorDelegate {
    func didCancel(in coordinator: EnterPasswordCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didEnterPassword(password: String, account: EthereumAccount, in coordinator: EnterPasswordCoordinator) {
        presentShareActivity(for: account, newPassword: password)
    }
}

extension BackupCoordinator: BackupSeedPhraseCoordinatorDelegate {
    func didTapTestSeedPhrase(forAccount account: EthereumAccount, inCoordinator coordinator: BackupSeedPhraseCoordinator) {
        let coordinator = VerifySeedPhraseCoordinator(navigationController: navigationController, keystore: keystore, account: account)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func didClose(forAccount account: EthereumAccount, inCoordinator coordinator: BackupSeedPhraseCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension BackupCoordinator: VerifySeedPhraseCoordinatorDelegate {
    func didVerifySeedPhraseSuccessfully(forAccount account: EthereumAccount, inCoordinator coordinator: VerifySeedPhraseCoordinator) {
        promptElevateSecurityOrEnd()
    }
}

extension BackupCoordinator: ElevateWalletSecurityCoordinatorDelegate {
    func didLockWalletSuccessfully(forAccount account: EthereumAccount, inCoordinator coordinator: ElevateWalletSecurityCoordinator) {
        cleanUpAfterBackupAndPromptedToElevateSecurity()
    }

    func didCancelLock(forAccount account: EthereumAccount, inCoordinator coordinator: ElevateWalletSecurityCoordinator) {
        cleanUpAfterBackupAndPromptedToElevateSecurity()
    }
}
