// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum Errors: LocalizedError {
    case invalidAddress
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return R.string.localizable.sendErrorInvalidAddress(preferredLanguages: Languages.preferred())
        case .invalidAmount:
            return R.string.localizable.sendErrorInvalidAmount(preferredLanguages: Languages.preferred())
        }
    }
}
