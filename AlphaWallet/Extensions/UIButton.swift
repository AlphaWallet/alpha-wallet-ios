// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension UIButton {
    func setBackgroundColor(_ color: UIColor, forState: UIControl.State) {
        color.isDynamic ? setDynamicColor(color, forState: forState) : setNonDynamicColor(color, forState: forState)
    }

    private func setDynamicColor(_ color: UIColor, forState: UIControl.State) {
        let imageAsset = UIImageAsset()

        let lightImage = UIImage(color: color.lightMode)!
        let lightMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .light)])
        imageAsset.register(lightImage, with: lightMode)

        let darkImage = UIImage(color: color.darkMode)!
        let darkMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .dark)])
        imageAsset.register(darkImage, with: darkMode)

        setBackgroundImage(imageAsset.image(with: .current), for: state)
    }

    private func setNonDynamicColor(_ color: UIColor, forState: UIControl.State) {
        UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
        UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
        UIGraphicsGetCurrentContext()!.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let colorImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        setBackgroundImage(colorImage, for: forState)
    }
}
