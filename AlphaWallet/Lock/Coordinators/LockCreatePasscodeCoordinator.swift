// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol LockCreatePasscodeCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: LockCreatePasscodeCoordinator)
}

class LockCreatePasscodeCoordinator: NSObject, Coordinator {
    private let lock: Lock
    private let navigationController: UINavigationController
    private lazy var lockViewController: LockCreatePasscodeViewController = {
        let viewModel = LockCreatePasscodeViewModel(lock: lock)
        let viewController = LockCreatePasscodeViewController(lockCreatePasscodeViewModel: viewModel)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        return viewController
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: LockCreatePasscodeCoordinatorDelegate?

    init(navigationController: UINavigationController, lock: Lock) {
        self.lock = lock
        self.navigationController = navigationController
    }

    func start() {
        navigationController.pushViewController(lockViewController, animated: true)
    }

    func stopTestOnly() {
        navigationController.popViewController(animated: true)
    }
}

extension LockCreatePasscodeCoordinator: LockCreatePasscodeViewControllerDelegate {
    func didSetPassword(in viewController: LockCreatePasscodeViewController) {
        navigationController.popViewController(animated: true)
    }

    func didClose(in viewController: LockCreatePasscodeViewController) {
        delegate?.didClose(in: self)
    }
}
