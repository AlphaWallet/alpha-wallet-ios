// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class LockEnterPasscodeCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	private let window: UIWindow = UIWindow()
	private let model: LockEnterPasscodeViewModel
	private let lock: LockInterface
	private lazy var lockEnterPasscodeViewController: LockEnterPasscodeViewController = {
		return LockEnterPasscodeViewController(model: model)
	}()
	init(model: LockEnterPasscodeViewModel, lock: LockInterface = Lock()) {
		self.window.windowLevel = UIWindowLevelStatusBar + 1.0
		self.model = model
		self.lock = lock
		lockEnterPasscodeViewController.unlockWithResult = { [weak self] (state, bioUnlock) in
			if state {
				self?.stop()
			}
		}
	}
	func start() {
		guard lock.isPasscodeSet() else { return }
		window.rootViewController = lockEnterPasscodeViewController
		window.makeKeyAndVisible()
	}
	func stop() {
		window.isHidden = true
	}

	func showAuthentication() {
		guard lock.isPasscodeSet() else { return }
		lockEnterPasscodeViewController.showKeyboard()
		lockEnterPasscodeViewController.showBioMerickAuth()
	}
}
