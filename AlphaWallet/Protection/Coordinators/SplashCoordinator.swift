// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class SplashCoordinator: Coordinator {
    private let window: UIWindow

    var coordinators: [Coordinator] = []

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        window.rootViewController = SplashViewController()
        window.isHidden = false
    }

    func stop() {
        window.isHidden = true
    }
}
