// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol BackupSeedPhraseCoordinatorDelegate: class {
    func didTapTestSeedPhrase(forAccount account: EthereumAccount, inCoordinator coordinator: BackupSeedPhraseCoordinator)
    func didClose(forAccount account: EthereumAccount, inCoordinator coordinator: BackupSeedPhraseCoordinator)
}

class BackupSeedPhraseCoordinator: Coordinator {
    private lazy var rootViewController: SeedPhraseBackupIntroductionViewController = {
        let controller = SeedPhraseBackupIntroductionViewController()
        controller.delegate = self
        controller.configure()
        return controller
    }()
    private lazy var showSeedPhraseViewController: ShowSeedPhraseViewController = {
        let controller = ShowSeedPhraseViewController(keystore: keystore, account: account)
        controller.configure()
        controller.delegate = self
        return controller
    }()
    private let account: EthereumAccount
    private let keystore: Keystore

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: BackupSeedPhraseCoordinatorDelegate?

    init(navigationController: UINavigationController = UINavigationController(), keystore: Keystore, account: EthereumAccount) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
    }

    func start() {
        navigationController.pushViewController(rootViewController, animated: true)
    }

    func end() {
        showSeedPhraseViewController.markDone()
    }

    func endUserInterface(animated: Bool) {
        let _ = navigationController.viewControllers.firstIndex(of: rootViewController)
                .flatMap { navigationController.viewControllers[$0 - 1] }
                .flatMap { navigationController.popToViewController($0, animated: animated) }
    }
}

extension BackupSeedPhraseCoordinator: ShowSeedPhraseViewControllerDelegate {
    func didTapTestSeedPhrase(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController) {
        delegate?.didTapTestSeedPhrase(forAccount: account, inCoordinator: self)
    }

    func didClose(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController) {
        delegate?.didClose(forAccount: account, inCoordinator: self)
    }
}

extension BackupSeedPhraseCoordinator: SeedPhraseBackupIntroductionViewControllerDelegate {
    func didTapBackupWallet(inViewController viewController: SeedPhraseBackupIntroductionViewController) {
        navigationController.pushViewController(showSeedPhraseViewController, animated: true)
    }
}
