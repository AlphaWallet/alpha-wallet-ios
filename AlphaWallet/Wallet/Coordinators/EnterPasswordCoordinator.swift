// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol EnterPasswordCoordinatorDelegate: class {
    func didEnterPassword(password: String, account: EthereumAccount, in coordinator: EnterPasswordCoordinator)
    func didCancel(in coordinator: EnterPasswordCoordinator)
}

class EnterPasswordCoordinator: CoordinatorThatEnds {
    private lazy var rootViewController: KeystoreBackupIntroductionViewController = {
        let controller = KeystoreBackupIntroductionViewController()
        controller.delegate = self
        controller.configure()
        return controller
    }()
    private let account: EthereumAccount

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: EnterPasswordCoordinatorDelegate?

    init(
        navigationController: UINavigationController = UINavigationController(),
        account: EthereumAccount
    ) {
        self.navigationController = navigationController
        self.account = account
    }

    func start() {
        rootViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(rootViewController, animated: true)
    }

    func end() {
        //do nothing
    }

    func endUserInterface(animated: Bool) {
        let _ = navigationController.viewControllers.firstIndex(of: rootViewController)
                .flatMap { navigationController.viewControllers[$0 - 1] }
                .flatMap { navigationController.popToViewController($0, animated: animated) }
    }

    func createEnterPasswordController() -> EnterPasswordViewController {
        let controller = EnterPasswordViewController(account: account)
        controller.delegate = self
        return controller
    }
}

extension EnterPasswordCoordinator: KeystoreBackupIntroductionViewControllerDelegate {
    func didTapExport(inViewController viewController: KeystoreBackupIntroductionViewController) {
        let vc = createEnterPasswordController()
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(vc, animated: true)
    }
}

extension EnterPasswordCoordinator: EnterPasswordViewControllerDelegate {
    func didEnterPassword(password: String, for account: EthereumAccount, inViewController viewController: EnterPasswordViewController) {
        delegate?.didEnterPassword(password: password, account: account, in: self)
    }
}
