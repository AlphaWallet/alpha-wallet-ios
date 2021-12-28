//
//  UIBarButtonItem.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.08.2021.
//

import UIKit

extension UIBarButtonItem {
    static func selectBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(title: R.string.localizable.aWalletTokenSelectTokens(), style: .plain, target: target, action: selector)
    }

    static func cancelBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(barButtonSystemItem: .cancel, target: target, action: selector)
    }

    static func closeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.close(), style: .plain, target: target, action: selector)
    }

    static func backBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.backWhite(), style: .plain, target: target, action: selector)
    }

    static func addButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.iconsSystemPlus(), style: .plain, target: target, action: selector)
    }

    static func qrCodeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.qr_code_icon(), style: .plain, target: target, action: selector)
    }

    static func myqrCodeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.qrRounded(), style: .plain, target: target, action: selector)
    }

    static func moreBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.toolbarMenu(), style: .plain, target: target, action: selector)
    }

    static func addBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.add_hide_tokens(), style: .plain, target: target, action: selector)
    }

    static func saveBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        .init(title: R.string.localizable.save(), style: .plain, target: target, action: selector)
    }

    static func backBarButton(selectionClosure: @escaping () -> Void) -> UIBarButtonItem {
        let barButton = UIBarButtonItem(image: R.image.backWhite(), style: .plain, target: nil, action: nil)
        barButton.selectionClosure = selectionClosure

        return barButton
    }

    private struct AssociatedObject {
        static var key = "action_closure_key"
    }

    var selectionClosure: (() -> Void)? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObject.key) as? () -> Void
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObject.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            target = self
            action = #selector(didTapButton)
        }
    }

    @objc func didTapButton(_ sender: Any) {
        selectionClosure?()
    }
}
