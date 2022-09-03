// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class LockEnterPasscodeCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	let window: UIWindow = UIWindow()
    private let lock: Lock
	private lazy var lockEnterPasscodeViewController: LockEnterPasscodeViewController = {
        let viewModel = LockEnterPasscodeViewModel(lock: lock)
		return LockEnterPasscodeViewController(lockEnterPasscodeViewModel: viewModel)
	}()

    init(lock: Lock) {
        self.lock = lock
		self.window.windowLevel = UIWindow.Level.statusBar + 1.0

		lockEnterPasscodeViewController.unlockWithResult = { [weak self] (state, bioUnlock) in
			if state {
				self?.stop()
			}
		}
	}
	func start() {
        guard lock.isPasscodeSet else { return }
		window.rootViewController = lockEnterPasscodeViewController
		window.makeKeyAndVisible()
	}
	func stop() {
		window.isHidden = true
	}

	func showAuthentication() {
        guard lock.isPasscodeSet else { return }
		lockEnterPasscodeViewController.showKeyboard()
		lockEnterPasscodeViewController.showBioMetricAuth()
	}
}
