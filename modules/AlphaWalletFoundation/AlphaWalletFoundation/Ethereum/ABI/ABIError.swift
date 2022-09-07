// Copyright © 2017-2018 Trust.
//
// This file is part of Trust. The full Trust copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation

public enum ABIError: LocalizedError {
    case integerOverflow
    case invalidUTF8String
    case invalidNumberOfArguments
    case invalidArgumentType
    case functionSignatureMismatch

    public var errorDescription: String? {
        switch self {
        case .integerOverflow:
            return NSLocalizedString("Integer overflow", comment: "ABI encoder error")
        case .invalidUTF8String:
            return NSLocalizedString("Can't encode string as UTF8", comment: "ABI encoder error")
        case .invalidNumberOfArguments:
            return NSLocalizedString("Invalid number of arguments", comment: "ABI error description")
        case .invalidArgumentType:
            return NSLocalizedString("Invalid argument type", comment: "ABI error description")
        case .functionSignatureMismatch:
            return NSLocalizedString("Function signature mismatch", comment: "ABI error description")
        }
    }
}
