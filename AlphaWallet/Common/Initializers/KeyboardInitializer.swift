//
//  KeyboardInitializer.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.11.2022.
//

import Foundation
import IQKeyboardManager
import AlphaWalletFoundation

final class KeyboardInitializer: Initializer {
    func perform() {
        IQKeyboardManager.shared().isEnabled = true
        IQKeyboardManager.shared().isEnableAutoToolbar = false
        IQKeyboardManager.shared().shouldResignOnTouchOutside = false
        IQKeyboardManager.shared().previousNextDisplayMode = .alwaysHide
        IQKeyboardManager.shared().shouldShowToolbarPlaceholder = false
    }
}
