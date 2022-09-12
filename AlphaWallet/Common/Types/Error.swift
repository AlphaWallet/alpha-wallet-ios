// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import APIKit
import AlphaWalletFoundation

extension KeystoreError {
    public var errorDescription: String? {
        switch self {
        case .failedToDeleteAccount:
            return R.string.localizable.accountsDeleteErrorFailedToDeleteAccount()
        case .failedToDecryptKey:
            return R.string.localizable.accountsDeleteErrorFailedToDecryptKey()
        case .failedToImport(let error):
            return error.localizedDescription
        case .duplicateAccount:
            return R.string.localizable.accountsDeleteErrorDuplicateAccount()
        case .failedToSignTransaction:
            return R.string.localizable.accountsDeleteErrorFailedToSignTransaction()
        case .failedToCreateWallet:
            return R.string.localizable.accountsDeleteErrorFailedToCreateWallet()
        case .failedToImportPrivateKey:
            return R.string.localizable.accountsDeleteErrorFailedToImportPrivateKey()
        case .failedToParseJSON:
            return R.string.localizable.accountsDeleteErrorFailedToParseJSON()
        case .accountNotFound:
            return R.string.localizable.accountsDeleteErrorAccountNotFound()
        case .failedToSignMessage:
            return R.string.localizable.accountsDeleteErrorFailedToSignMessage()
        case .failedToExportPrivateKey:
            return R.string.localizable.accountsDeleteErrorFailedToExportPrivateKey()
        case .failedToExportSeed:
            return R.string.localizable.accountsDeleteErrorFailedToExportSeed()
        case .accountMayNeedImportingAgainOrEnablePasscode:
            return R.string.localizable.keystoreAccessKeyNeedImportOrPasscode()
        case .userCancelled:
            return R.string.localizable.keystoreAccessKeyCancelled()
        }
    }
}

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
        case let error as KeystoreError:
            return error.errorDescription ?? UnknownError().localizedDescription
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