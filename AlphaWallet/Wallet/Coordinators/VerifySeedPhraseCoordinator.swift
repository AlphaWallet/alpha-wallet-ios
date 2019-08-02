// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol VerifySeedPhraseCoordinatorDelegate: class {
    func didVerifySeedPhraseSuccessfully(forAccount account: EthereumAccount, inCoordinator coordinator: VerifySeedPhraseCoordinator)
}

class VerifySeedPhraseCoordinator: Coordinator {
    private lazy var rootViewController: VerifySeedPhraseViewController = {
        let controller = VerifySeedPhraseViewController(keystore: keystore, account: account)
        controller.configure()
        controller.delegate = self
        return controller
    }()
    private let account: EthereumAccount
    private let keystore: Keystore

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: VerifySeedPhraseCoordinatorDelegate?

    init(navigationController: UINavigationController = UINavigationController(), keystore: Keystore, account: EthereumAccount) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.account = account
    }

    func start() {
        navigationController.pushViewController(rootViewController, animated: true)
    }

    func end() {
        //do nothing
    }

    func endUserInterface(animated: Bool) {
        navigationController.popViewController(animated: animated)
    }
}

extension VerifySeedPhraseCoordinator: VerifySeedPhraseViewControllerDelegate {
    func didVerifySeedPhraseSuccessfully(for account: EthereumAccount, in viewController: VerifySeedPhraseViewController) {
        delegate?.didVerifySeedPhraseSuccessfully(forAccount: account, inCoordinator: self)
    }
}
