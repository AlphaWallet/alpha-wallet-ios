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

    public var customValue: Double? {
        switch self {
        case .onePercents, .fivePercents, .tenPercents: return nil
        case .custom(let double): return double
        }
    }
    /// Max available slippage value equals of 100 percents, might causing loosing of all tokens
    public static let max: Double = 1
    public static let toPercentageUnits: Double = 100.0
    public static var allCases: [SwapSlippage] = [.onePercents, .fivePercents, .tenPercents, .custom(0.0)]

    public var doubleValue: Double {
        switch self {
        case .onePercents: return SwapSlippage.rawValue(from: 1)
        case .fivePercents: return SwapSlippage.rawValue(from: 5)
        case .tenPercents: return SwapSlippage.rawValue(from: 10)
        case .custom(let double): return double
        }
    }

    public var title: String {
        switch self {
        case .onePercents: return "1 %"
        case .fivePercents: return "5 %"
        case .tenPercents: return "10 %"
        case .custom(let double): return "\(double * SwapSlippage.toPercentageUnits) %"
        }
    }

    public var shouldResignActiveTextFieldWhenOtherSelected: Bool {
        switch self {
        case .onePercents, .fivePercents, .tenPercents: return true
        case .custom: return false
        }
    }

    public static func rawValue(from percents: Double) -> Double {
        return percents * SwapSlippage.max / 100
    }

    public static func custom(from value: Double) -> SwapSlippage {
        return SwapSlippage.custom(min(value * SwapSlippage.max / SwapSlippage.toPercentageUnits, SwapSlippage.max))
    }
}
