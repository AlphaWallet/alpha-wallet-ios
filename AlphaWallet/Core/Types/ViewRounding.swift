//
//  ViewRounding.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit

enum ViewRounding {
    case none
    case circle
    case custom(CGFloat)

    func cornerRadius(view: UIView) -> CGFloat {
        switch self {
        case .none:
            return 0
        case .circle:
            return view.bounds.width / 2
        case .custom(let cGFloat):
            return cGFloat
        }
    }
}
