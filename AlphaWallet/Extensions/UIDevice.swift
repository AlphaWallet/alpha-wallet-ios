//
//  UIDevice.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import AlphaWalletFoundation
import UIKit

extension UIDevice {

    public static var isSafeAreaPhone: Bool {
        return AlphaWallet.Device.isPhone && isSafeAreaDevice
    }

    public static var isSafeAreaPad: Bool {
        return AlphaWallet.Device.isPad && isSafeAreaDevice
    }

    public static var isSafeAreaDevice: Bool {
        guard let safeAreaInsets = UIApplication.shared.firstKeyWindow?.safeAreaInsets else {
            return false
        }

        // iOS11 top value is 0,but iOS12 top is 20.
        let hasSafeArea = (safeAreaInsets.top != 0 && safeAreaInsets.top != 20) || safeAreaInsets.bottom != 0 || safeAreaInsets.left != 0 || safeAreaInsets.right != 0
        return hasSafeArea
    }
}
