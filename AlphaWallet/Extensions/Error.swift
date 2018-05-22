// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit
import Result

extension Error {
    var prettyError: String {
        switch self {
        case let error as AnyError:
            switch error.error {
            case let error as APIKit.SessionTaskError:
                switch error {
                case .connectionError(let error):
                    return error.localizedDescription
                case .requestError(let error):
                    return error.localizedDescription
                case .responseError(let error):
                    guard let JSONError = error as? JSONRPCError else {
                        return error.localizedDescription
                    }
                    switch JSONError {
                    case .responseError(_, let message, _):
                        return message
                    default: return R.string.localizable.undefinedError()
                    }
                }
            default:
                return error.errorDescription ?? error.description
            }
        case let error as LocalizedError:
            return error.errorDescription ?? R.string.localizable.unknownError()
        case let error as NSError:
            return error.localizedDescription
        default:
            return R.string.localizable.undefinedError()
        }
    }

    var code: Int { return (self as NSError).code }
    var domain: String { return (self as NSError).domain }
}
