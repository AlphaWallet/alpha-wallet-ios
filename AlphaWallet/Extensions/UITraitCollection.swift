//
//  UITraitCollection.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import UIKit
import AlphaWalletFoundation

extension UITraitCollection {
    var uniswapTheme: Uniswap.Theme {
        switch userInterfaceStyle {
        case .dark:
            return .dark
        case .light, .unspecified:
            return .light
        }
    }
}

extension UITraitCollection {
    var honeyswapTheme: HoneySwap.Theme {
        switch userInterfaceStyle {
        case .dark:
            return .dark
        case .light, .unspecified:
            return .light
        }
    }
}
