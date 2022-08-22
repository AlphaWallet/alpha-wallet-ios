//
//  SwapSlippage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation

enum SwapSlippage: Equatable {
    case tenPercents
    case fiftyPercents
    case oneHundredPercents
    case custom(Double)

    var customValue: Double? {
        switch self {
        case .tenPercents, .fiftyPercents, .oneHundredPercents: return nil
        case .custom(let double): return double
        }
    }

    var doubleValue: Double {
        switch self {
        case .tenPercents: return 0.1
        case .fiftyPercents: return 0.5
        case .oneHundredPercents: return 1.0
        case .custom(let double): return double
        }
    }

    var title: String {
        switch self {
        case .tenPercents: return "10 %"
        case .fiftyPercents: return "50 %"
        case .oneHundredPercents: return "100 %"
        case .custom(let double): return "\(double) %"
        }
    }

    var shouldResignActiveTextFieldWhenOtherSelected: Bool {
        switch self {
        case .tenPercents, .fiftyPercents, .oneHundredPercents: return true
        case .custom: return false
        }
    }

    var viewType: SlippageViewModel.SwapSlippageViewType {
        switch self {
        case .tenPercents, .fiftyPercents, .oneHundredPercents: return .selectionButton
        case .custom: return .editingTextField
        }
    }
}
