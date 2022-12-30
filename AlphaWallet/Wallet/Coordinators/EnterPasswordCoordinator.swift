// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation

protocol EnterPasswordCoordinatorDelegate: AnyObject {
    func didEnterPassword(password: String, account: AlphaWallet.Address, in coordinator: EnterPasswordCoordinator)
    func didCancel(in coordinator: EnterPasswordCoordinator)
}

class EnterPasswordCoordinator: Coordinator {
    private lazy var rootViewController: KeystoreBackupIntroductionViewController = {
        let controller = KeystoreBackupIntroductionViewController()
        controller.delegate = self
        controller.configure()
        return controller
    }()
    private let account: AlphaWallet.Address

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: EnterPasswordCoordinatorDelegate?

    init(navigationController: UINavigationController = NavigationController(),
         account: AlphaWallet.Address) {
        self.navigationController = navigationController
        self.account = account
    }

    func start() {
        rootViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(rootViewController, animated: true)
    }
}

extension EnterPasswordCoordinator: KeystoreBackupIntroductionViewControllerDelegate {
    func didTapExport(in viewController: KeystoreBackupIntroductionViewController) {
        let controller = EnterKeystorePasswordViewController(viewModel: EnterKeystorePasswordViewModel())
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(controller, animated: true)
    }

    func didClose(in viewController: KeystoreBackupIntroductionViewController) {
        delegate?.didCancel(in: self)
    }
}

extension EnterPasswordCoordinator: EnterKeystorePasswordViewControllerDelegate {
    func didClose(in viewController: EnterKeystorePasswordViewController) {
        //no-op
    }

    func didEnterPassword(password: String, in viewController: EnterKeystorePasswordViewController) {
        delegate?.didEnterPassword(password: password, account: account, in: self)
    }
}
