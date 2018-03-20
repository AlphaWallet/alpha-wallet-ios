// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class LockCreatePasscodeCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private let model: LockCreatePasscodeViewModel
    private let navigationController: UINavigationController
    lazy var lockViewController: LockCreatePasscodeViewController = {
        return LockCreatePasscodeViewController(model: model)
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
