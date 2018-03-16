// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//Duplicated from LockCreatePasscodeCoordinator.swift for easier upstream merging
class AlphaWalletLockCreatePasscodeCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private let model: LockCreatePasscodeViewModel
    private let navigationController: UINavigationController
    lazy var lockViewController: AlphaWalletLockCreatePasscodeViewController = {
        return AlphaWalletLockCreatePasscodeViewController(model: model)
    }()
    init(navigationController: UINavigationController, model: LockCreatePasscodeViewModel) {
        self.navigationController = navigationController
        self.model = model
    }
    func start() {
        navigationController.pushViewController(lockViewController, animated: true)
    }
    func stop() {
        navigationController.popViewController(animated: true)
    }
}
