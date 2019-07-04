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

    func finish(result: Result<Bool, AnyError>) {
        switch result {
        case .success:
            delegate?.didFinish(account: account, in: self)
        case .failure:
            delegate?.didCancel(coordinator: self)
        }
    }

    func presentActivityViewController(for account: EthereumAccount, newPassword: String, coordinator: CoordinatorThatEnds, completion: @escaping (Result<Bool, AnyError>) -> Void) {
        navigationController.displayLoading(
            text: R.string.localizable.exportPresentBackupOptionsLabelTitle()
        )
        keystore.exportRawPrivateKeyForNonHdWallet(forAccount: account, newPassword: newPassword) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.handleExport(result: result, coordinator: coordinator, completion: completion)
        }
    }

    private func handleExport(result: (Result<String, KeystoreError>), coordinator: CoordinatorThatEnds, completion: @escaping (Result<Bool, AnyError>) -> Void) {
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
                coordinator.end(animated: true)
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

    func presentShareActivity(for account: EthereumAccount, newPassword: String, coordinator: CoordinatorThatEnds) {
        presentActivityViewController(for: account, newPassword: newPassword, coordinator: coordinator) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.finish(result: result)
        }
    }

    func export(for account: EthereumAccount) {
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
}

extension BackupCoordinator: EnterPasswordCoordinatorDelegate {
    func didCancel(in coordinator: EnterPasswordCoordinator) {
        coordinator.navigationController.dismiss(animated: true, completion: nil)
        removeCoordinator(coordinator)
    }

    func didEnterPassword(password: String, account: EthereumAccount, in coordinator: EnterPasswordCoordinator) {
        presentShareActivity(for: account, newPassword: password, coordinator: coordinator)
        removeCoordinator(coordinator)
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
        let backupSeedPhraseCoordinator = coordinators.first { $0 is BackupSeedPhraseCoordinator } as? BackupSeedPhraseCoordinator
        defer { backupSeedPhraseCoordinator.flatMap { removeCoordinator($0) } }
        defer { removeCoordinator(coordinator) }
        backupSeedPhraseCoordinator?.end(animated: false)
        coordinator.end(animated: true)
    }
}
