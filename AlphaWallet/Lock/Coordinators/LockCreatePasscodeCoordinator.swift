// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class LockCreatePasscodeCoordinator: Coordinator {
    private let lock: Lock
    private let navigationController: UINavigationController
    lazy var lockViewController: LockCreatePasscodeViewController = {
        let viewModel = LockCreatePasscodeViewModel(lock: lock)
        return LockCreatePasscodeViewController(lockCreatePasscodeViewModel: viewModel)
    }()
    var coordinators: [Coordinator] = []

    init(navigationController: UINavigationController, lock: Lock) {
        self.lock = lock
        self.navigationController = navigationController
    }
    func start() {
        lockViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(lockViewController, animated: true)
    }
    func stop() {
        navigationController.popViewController(animated: true)
    }
}
