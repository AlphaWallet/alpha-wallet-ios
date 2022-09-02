// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import APIKit
import JSONRPCKit
import web3swift

public struct UndefinedError: LocalizedError { }
public struct UnknownError: LocalizedError { }

extension Error {
    public var prettyError: String {
        switch self {
        case let error as BuyCryptoError:
            return error.localizedDescription
        case let error as ActiveWalletError:
            return error.localizedDescription
        case let error as SwapTokenError:
            return error.localizedDescription
        case let error as WalletApiError:
            return error.localizedDescription
        case let error as FunctionError:
            return error.localizedDescription
        case let error as TransactionConfiguratorError:
            return error.localizedDescription
        case let error as RequestCanceledDueToWatchWalletError:
            return error.localizedDescription
        case let error as LocalizedError:
            return error.errorDescription ?? UnknownError().localizedDescription
        case let error as NSError:
            return error.localizedDescription
        case let error as APIKit.SessionTaskError:
            return generatePrettyError(forSessionTaskError: error)
        default:
            return UndefinedError().localizedDescription
        }
    }

    public var code: Int { return (self as NSError).code }
    public var domain: String { return (self as NSError).domain }

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
                return UndefinedError().localizedDescription
            }
        }
    }
}
