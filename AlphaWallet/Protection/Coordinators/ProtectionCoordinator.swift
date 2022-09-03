// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class ProtectionCoordinator: Coordinator {
	private lazy var splashCoordinator: SplashCoordinator = {
		return SplashCoordinator(window: protectionWindow)
	}()

	private lazy var lockEnterPasscodeCoordinator: LockEnterPasscodeCoordinator = {
        return LockEnterPasscodeCoordinator(lock: lock)
	}()

	private let protectionWindow = UIWindow()
    private let lock: Lock
	var coordinators: [Coordinator] = []

	init(lock: Lock) {
        self.lock = lock
		protectionWindow.windowLevel = UIWindow.Level.statusBar + 2.0
	}

	func didFinishLaunchingWithOptions() {
		//Not calling `splashCoordinator.start()` here because it seems unnecessary, and most importantly, the implementation (changing `UIWindow.rootViewController`) seems to be (one of?) the reason why the app hangs at the splash screen at launch sometimes
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
