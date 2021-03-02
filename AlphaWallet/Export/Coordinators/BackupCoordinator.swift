// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result

protocol BackupCoordinatorDelegate: class {
    func didCancel(coordinator: BackupCoordinator)
    func didFinish(account: AlphaWallet.Address, in coordinator: BackupCoordinator)
}

class BackupCoordinator: Coordinator {
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private let analyticsCoordinator: AnalyticsCoordinator

    let navigationController: UINavigationController
    weak var delegate: BackupCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(navigationController: UINavigationController, keystore: Keystore, account: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
        self.analyticsCoordinator = analyticsCoordinator
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        export()
    }

    private func finish(result: Result<Bool, AnyError>) {
        switch result {
        case .success:
            delegate?.didFinish(account: account, in: self)
        case .failure:
            delegate?.didCancel(coordinator: self)
        }
    }

    private func presentActivityViewController(for account: AlphaWallet.Address, newPassword: String, completion: @escaping (Result<Bool, AnyError>) -> Void) {
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
            let url = URL(fileURLWithPath: NSTemporaryDirectory().appending("alphawallet_backup_\(account.eip55String).json"))
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

    private func presentShareActivity(for account: AlphaWallet.Address, newPassword: String ) {
        presentActivityViewController(for: account, newPassword: newPassword) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let isBackedUp):
                if isBackedUp {
                    strongSelf.promptElevateSecurityOrEnd()
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

    private func export() {
        if keystore.isHdWallet(account: account) {
            let coordinator = BackupSeedPhraseCoordinator(navigationController: navigationController, keystore: keystore, account: account, analyticsCoordinator: analyticsCoordinator)
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
        let enterPasswordCoordinator = coordinators.first { $0 is EnterPasswordCoordinator } as? EnterPasswordCoordinator
        defer { enterPasswordCoordinator.flatMap { removeCoordinator($0) } }

        enterPasswordCoordinator?.end()
        backupSeedPhraseCoordinator?.end()
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
        let enterPasswordCoordinator = coordinators.first { $0 is EnterPasswordCoordinator } as? EnterPasswordCoordinator
        defer { enterPasswordCoordinator.flatMap { removeCoordinator($0) } }

        enterPasswordCoordinator?.end()
        backupSeedPhraseCoordinator?.end()

        //Must only call endUserInterface() on the coordinators managing the bottom-most view controller
        //Only one of these 2 coordinators will be nil
        backupSeedPhraseCoordinator?.endUserInterface(animated: true)
        enterPasswordCoordinator?.endUserInterface(animated: true)

        finish(result: .success(true))
        //Bit of delay to wait for UI animation to almost finish
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

    func didEnterPassword(password: String, account: AlphaWallet.Address, in coordinator: EnterPasswordCoordinator) {
        presentShareActivity(for: account, newPassword: password)
    }
}

extension BackupCoordinator: BackupSeedPhraseCoordinatorDelegate {
    func didClose(forAccount account: AlphaWallet.Address, inCoordinator coordinator: BackupSeedPhraseCoordinator) {
        removeCoordinator(coordinator)
    }

    func didVerifySeedPhraseSuccessfully(forAccount account: AlphaWallet.Address, inCoordinator coordinator: BackupSeedPhraseCoordinator) {
        promptElevateSecurityOrEnd()
    }
}

extension BackupCoordinator: ElevateWalletSecurityCoordinatorDelegate {
    func didLockWalletSuccessfully(forAccount account: AlphaWallet.Address, inCoordinator coordinator: ElevateWalletSecurityCoordinator) {
        cleanUpAfterBackupAndPromptedToElevateSecurity()
    }

    func didCancelLock(forAccount account: AlphaWallet.Address, inCoordinator coordinator: ElevateWalletSecurityCoordinator) {
        cleanUpAfterBackupAndPromptedToElevateSecurity()
    }
}
