// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension UIButton {
    /// darkModeEnabled - for now not all screens support for dark mode, checkout each UIButton where `setBackgroundColor` get called.
    func setBackgroundColor(_ color: UIColor, forState: UIControl.State, darkModeEnabled: Bool) {
        if darkModeEnabled {
            let imageAsset = UIImageAsset()

            let lightImage = UIImage(color: color.lightMode)!
            let lightMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .light)])
            imageAsset.register(lightImage, with: lightMode)

            let darkImage = UIImage(color: color.darkMode)!
            let darkMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .dark)])
            imageAsset.register(darkImage, with: darkMode)

            setBackgroundImage(imageAsset.image(with: .current), for: state)
        } else {
            UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
            UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
            UIGraphicsGetCurrentContext()!.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            let colorImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            setBackgroundImage(colorImage, for: forState)
        }
    }
}
