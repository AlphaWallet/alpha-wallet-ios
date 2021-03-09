//
//  UIResponder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.03.2021.
//

import UIKit

extension UIResponder {

    func next<T: UIResponder>(_ type: T.Type) -> T? {
        return next as? T ?? next?.next(type)
    }
}
