//
//  SwapSlippage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation

enum SwapSlippage: Equatable {
    case dotOne
    case dotFive
    case one
    case custom(Double)

    var customValue: Double? {
        switch self {
        case .dotOne, .dotFive, .one: return nil
        case .custom(let double): return double
        }
    }

    var doubleValue: Double {
        switch self {
        case .dotOne: return 0.1
        case .dotFive: return 0.5
        case .one: return 1.0
        case .custom(let double): return double
        }
    }

    var title: String {
        switch self {
        case .dotOne: return "0.1 %"
        case .dotFive: return "0.5 %"
        case .one: return "1.0 %"
        case .custom(let double): return "\(double) %"
        }
    }

    var shouldResignActiveTextFieldWhenOtherSelected: Bool {
        switch self {
        case .dotOne, .dotFive, .one: return true
        case .custom: return false
        }
    }

    var viewType: SlippageViewModel.SwapSlippageViewType {
        switch self {
        case .dotOne, .dotFive, .one: return .selectionButton
        case .custom: return .editingTextField
        }
    }
}
