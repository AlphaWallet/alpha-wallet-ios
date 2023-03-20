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
    var placeholderRounding: ViewRounding { get set }
}

enum ViewLoading {
    case enabled
    case disabled
}

protocol ViewLoadingSupportable {
    var loading: ViewLoading { get set }

    func cancel()
}

enum ViewRounding {
    case none
    case circle
    case custom(CGFloat)

    func cornerRadius(view: UIView) -> CGFloat {
        switch self {
        case .none:
            return 0
        case .circle:
            return view.bounds.height / 2
        case .custom(let cGFloat):
            return cGFloat
        }
    }
}
