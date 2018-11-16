// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class TabBarController: UITabBarController {

    var didShake: (() -> Void)?

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        didShake?()
    }
}
