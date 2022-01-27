// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

private var splashViewController: UIViewController?

func SplashViewController() -> UIViewController {
    if let value = splashViewController {
        return value
    } else {
        splashViewController = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
    }
    return splashViewController!
}
