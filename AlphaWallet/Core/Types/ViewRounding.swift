//
//  ViewRounding.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit
import Kingfisher

protocol ContentBackgroundSupportable {
    var contentBackgroundColor: UIColor? { get set }
}

protocol ViewRoundingSupportable {
    var rounding: ViewRounding { get set }
}

protocol ViewLoadingCancelable {
    func cancel()
}

enum ViewRounding {
    case none
    case circle
    case custom(CGFloat)

    func cornerRadius(view: UIView) -> Radius {
        switch self {
        case .none:
            return .point(0)
        case .circle:
            return .heightFraction(0.5)// view.bounds.width / 2
        case .custom(let cGFloat):
            return .point(cGFloat * 10)
        }
    }

    func cornerRadius2(view: UIView) -> CGFloat {
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
