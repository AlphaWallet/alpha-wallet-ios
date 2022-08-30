//
//  UIToolbar+Custom.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.08.2021.
//

import UIKit

class CustomToolbar: UIToolbar {
    private let height: CGFloat

    override init(frame: CGRect) {
        height = frame.height
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        super.sizeThatFits(size)
        var sizeThatFits = super.sizeThatFits(size)
        sizeThatFits.height = height

        return sizeThatFits
    }
}

extension UIToolbar {

    static func doneToolbarButton(_ selector: Selector, _ target: AnyObject) -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: target, action: selector)

        toolbar.items = [flexSpace, done]
        toolbar.sizeToFit()

        return toolbar
    }

    static func nextToolbarButton(_ selector: Selector, _ target: AnyObject) -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let next = UIBarButtonItem(title: R.string.localizable.next(), style: .plain, target: target, action: selector)
        toolbar.items = [flexSpace, next]
        toolbar.sizeToFit()

        return toolbar
    }

    static func customToolbar(with customView: UIView, height: CGFloat) -> UIToolbar {
        let toolbar = CustomToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: height))
        toolbar.barStyle = .default

        toolbar.items = [UIBarButtonItem(customView: customView)]
        toolbar.sizeToFit()

        return toolbar
    }
}
