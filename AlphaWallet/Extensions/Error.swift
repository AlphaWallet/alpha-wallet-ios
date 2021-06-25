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
                return generatePrettyError(forSessionTaskError: error)
            default:
                return error.errorDescription ?? error.description
            }
        case let error as LocalizedError:
            return error.errorDescription ?? R.string.localizable.unknownError()
        case let error as NSError:
            return error.localizedDescription
        case let error as APIKit.SessionTaskError:
            return generatePrettyError(forSessionTaskError: error)
        default:
            return R.string.localizable.undefinedError()
        }
    }

    var code: Int { return (self as NSError).code }
    var domain: String { return (self as NSError).domain }

    private func generatePrettyError(forSessionTaskError error: APIKit.SessionTaskError) -> String {
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
            case .responseNotFound, .resultObjectParseError, .errorObjectParseError, .unsupportedVersion, .unexpectedTypeObject, .missingBothResultAndError, .nonArrayResponse:
                return R.string.localizable.undefinedError()
            }
        }
    }
}