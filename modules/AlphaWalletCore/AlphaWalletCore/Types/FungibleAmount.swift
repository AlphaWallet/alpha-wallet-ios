// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public enum FungibleAmount {
    public enum AmountType {
        case fiat(value: Double, currency: Currency)
        case crypto(value: Double)
    }

    case amount(Double)
    case allFunds
    case notSet

    public var isAllFunds: Bool {
        switch self {
        case .allFunds: return true
        case .notSet, .amount: return false
        }
    }
}

extension FungibleAmount: Equatable {
    public static func == (lhs: FungibleAmount, rhs: FungibleAmount) -> Bool {
        switch (lhs, rhs) {
        case (.amount(let a1), amount(let a2)):
            return a1 == a2
        case (.allFunds, .allFunds):
            return true
        case (.notSet, .notSet):
            return true
        case (.amount, .notSet), (.amount, .allFunds), (.allFunds, .notSet), (.notSet, .amount), (.notSet, .allFunds), (.allFunds, .amount):
            return false
        }
    }
}
