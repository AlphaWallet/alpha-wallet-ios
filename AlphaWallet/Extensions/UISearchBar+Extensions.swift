//
//  UISearchBar+Extensions.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit

extension UISearchBar {

    var textField: UITextField? {
        return getTextField(inViews: subviews)
    }

    private func getTextField(inViews views: [UIView]?) -> UITextField? {
        guard let views = views else { return nil }

        for view in views {
            if let textField = (view as? UITextField) ?? getTextField(inViews: view.subviews) {
                return textField
            }
        }

        return nil
    }
}
