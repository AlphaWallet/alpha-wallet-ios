//
//  UIImageAsset+Extension.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/8/22.
//

import UIKit

extension UIImageAsset {
    static func dynamicColorImageAsset(_ color: UIColor) -> UIImageAsset {
        let imageAsset = UIImageAsset()

        let lightImage = UIImage(color: color.lightMode)!
        let lightMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .light)])
        imageAsset.register(lightImage, with: lightMode)

        let darkImage = UIImage(color: color.darkMode)!
        let darkMode = UITraitCollection(traitsFrom: [.init(userInterfaceStyle: .dark)])
        imageAsset.register(darkImage, with: darkMode)

        return imageAsset
    }
}
