//
//  File.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.05.2022.
//

import UIKit

extension UIApplication {
    var keyboardHostView: UIView? {
        windows
        .filter { NSStringFromClass($0.classForCoder) == "UIRemoteKeyboardWindow" }
        .first?.subviews.filter { NSStringFromClass($0.classForCoder) == "UIInputSetContainerView" }
        .first?.subviews.filter { NSStringFromClass($0.classForCoder) == "UIInputSetHostView" }
        .first
    }

    var bottomSafeAreaHeight: CGFloat {

        let window = UIApplication.shared.windows[0]
        let safeFrame = window.safeAreaLayoutGuide.layoutFrame

        return window.frame.maxY - safeFrame.maxY
    }

    var firstKeyWindow: UIWindow? {
        windows.filter { $0.isKeyWindow }.first
    }

    func presentedViewController(or defaultViewControler: UIViewController) -> UIViewController {
        guard let keyWindow = UIApplication.shared.firstKeyWindow else { return defaultViewControler }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            return controller
        } else {
            return defaultViewControler
        }
    }

}
