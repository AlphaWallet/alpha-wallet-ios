// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum InputError: LocalizedError {
    case invalidAddress
    case invalidAmount

    public var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return R.string.localizable.sendErrorInvalidAddress()
        case .invalidAmount:
            return R.string.localizable.sendErrorInvalidAmount()
        }
    }

}
