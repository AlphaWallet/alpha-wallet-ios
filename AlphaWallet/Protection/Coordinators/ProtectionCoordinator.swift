// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ProtectionCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	lazy var splashCoordinator: SplashCoordinator = {
		return SplashCoordinator(window: self.protectionWindow)
	}()
	lazy var lockEnterPasscodeCoordinator: LockEnterPasscodeCoordinator = {
		return LockEnterPasscodeCoordinator(model: LockEnterPasscodeViewModel())
	}()
	let protectionWindow = UIWindow()
	init() {
		protectionWindow.windowLevel = UIWindowLevelStatusBar + 2.0
	}

	func didFinishLaunchingWithOptions() {
		splashCoordinator.start()
		lockEnterPasscodeCoordinator.start()
		lockEnterPasscodeCoordinator.showAuthentication()
	}

	func applicationDidBecomeActive() {
		splashCoordinator.stop()
	}

	func applicationWillResignActive() {
		splashCoordinator.start()
	}

	func applicationDidEnterBackground() {
		splashCoordinator.start()
		lockEnterPasscodeCoordinator.start()
	}

	func applicationWillEnterForeground() {
		splashCoordinator.stop()
		lockEnterPasscodeCoordinator.start()
		lockEnterPasscodeCoordinator.showAuthentication()
	}
}
