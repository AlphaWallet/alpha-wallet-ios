// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

enum Errors: LocalizedError {
    case invalidAddress
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return R.string.localizable.sendErrorInvalidAddress()
        case .invalidAmount:
            return NSLocalizedString("send.error.invalidAmount", value: "Invalid Amount", comment: "")
        }
    }
}
