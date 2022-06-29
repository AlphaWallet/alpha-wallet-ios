// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension UIButton {
    func setBackgroundColor(_ color: UIColor, forState: UIControl.State) {
        let imageAsset = UIImageAsset()

        let lightImage = UIImage(color: color.lightMode)!
        let lightMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .light)])
        imageAsset.register(lightImage, with: lightMode)

        let darkImage = UIImage(color: color.darkMode)!
        let darkMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .dark)])
        imageAsset.register(darkImage, with: darkMode)

        setBackgroundImage(imageAsset.image(with: .current), for: state)
    }
}
