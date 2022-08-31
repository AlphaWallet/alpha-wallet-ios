//
//  SwapSlippage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import Foundation

public enum SwapSlippage: Equatable {
    case onePercents
    case fivePercents
    case tenPercents
    case custom(Double)

    var customValue: Double? {
        switch self {
        case .onePercents, .fivePercents, .tenPercents: return nil
        case .custom(let double): return double
        }
    }
    /// Max available slippage value equals of 100 percents, might causing loosing of all tokens
    static let max: Double = 1
    static let toPercentageUnits: Double = 100.0
    static var allCases: [SwapSlippage] = [.onePercents, .fivePercents, .tenPercents, .custom(0.0)]

    var doubleValue: Double {
        switch self {
        case .onePercents: return SwapSlippage.rawValue(from: 1)
        case .fivePercents: return SwapSlippage.rawValue(from: 5)
        case .tenPercents: return SwapSlippage.rawValue(from: 10)
        case .custom(let double): return double
        }
    }

    var title: String {
        switch self {
        case .onePercents: return "1 %"
        case .fivePercents: return "5 %"
        case .tenPercents: return "10 %"
        case .custom(let double): return "\(double * SwapSlippage.toPercentageUnits) %"
        }
    }

    var shouldResignActiveTextFieldWhenOtherSelected: Bool {
        switch self {
        case .onePercents, .fivePercents, .tenPercents: return true
        case .custom: return false
        }
    }

    static func rawValue(from percents: Double) -> Double {
        return percents * SwapSlippage.max / 100
    }

    static func custom(from value: Double) -> SwapSlippage {
        return SwapSlippage.custom(min(value * SwapSlippage.max / SwapSlippage.toPercentageUnits, SwapSlippage.max))
    }
}
