//
//  UIDevice.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import UIKit
import AlphaWalletFoundation

extension UIDevice {

    static public var isSafeAreaPhone: Bool {
        return AlphaWallet.Device.isPhone && isSafeAreaDevice
    }

    static public var isSafeAreaPad: Bool {
        return AlphaWallet.Device.isPad && isSafeAreaDevice
    }

    static public var isSafeAreaDevice: Bool {
        guard let safeAreaInsets = UIApplication.shared.firstKeyWindow?.safeAreaInsets else {
            return false
        }

        // iOS11 top value is 0,but iOS12 top is 20.
        let hasSafeArea = (safeAreaInsets.top != 0 && safeAreaInsets.top != 20) || safeAreaInsets.bottom != 0 || safeAreaInsets.left != 0 || safeAreaInsets.right != 0
        return  hasSafeArea
    }
}
