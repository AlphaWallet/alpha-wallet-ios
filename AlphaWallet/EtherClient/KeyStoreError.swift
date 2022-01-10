// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum KeystoreError: LocalizedError {
    case failedToDeleteAccount
    case failedToDecryptKey
    case failedToImport(Error)
    case duplicateAccount
    case failedToSignTransaction
    case failedToCreateWallet
    case failedToImportPrivateKey
    case failedToParseJSON
    case accountNotFound
    case failedToSignMessage
    case failedToExportPrivateKey
    case failedToExportSeed
    case accountMayNeedImportingAgainOrEnablePasscode
    case userCancelled

    public var errorDescription: String? {
        switch self {
        case .failedToDeleteAccount:
            return R.string.localizable.accountsDeleteErrorFailedToDeleteAccount(preferredLanguages: Languages.preferred())
        case .failedToDecryptKey:
            return R.string.localizable.accountsDeleteErrorFailedToDecryptKey(preferredLanguages: Languages.preferred())
        case .failedToImport(let error):
            return error.localizedDescription
        case .duplicateAccount:
            return R.string.localizable.accountsDeleteErrorDuplicateAccount(preferredLanguages: Languages.preferred())
        case .failedToSignTransaction:
            return R.string.localizable.accountsDeleteErrorFailedToSignTransaction(preferredLanguages: Languages.preferred())
        case .failedToCreateWallet:
            return R.string.localizable.accountsDeleteErrorFailedToCreateWallet(preferredLanguages: Languages.preferred())
        case .failedToImportPrivateKey:
            return R.string.localizable.accountsDeleteErrorFailedToImportPrivateKey(preferredLanguages: Languages.preferred())
        case .failedToParseJSON:
            return R.string.localizable.accountsDeleteErrorFailedToParseJSON(preferredLanguages: Languages.preferred())
        case .accountNotFound:
            return R.string.localizable.accountsDeleteErrorAccountNotFound(preferredLanguages: Languages.preferred())
        case .failedToSignMessage:
            return R.string.localizable.accountsDeleteErrorFailedToSignMessage(preferredLanguages: Languages.preferred())
        case .failedToExportPrivateKey:
            return R.string.localizable.accountsDeleteErrorFailedToExportPrivateKey(preferredLanguages: Languages.preferred())
        case .failedToExportSeed:
            return R.string.localizable.accountsDeleteErrorFailedToExportSeed(preferredLanguages: Languages.preferred())
        case .accountMayNeedImportingAgainOrEnablePasscode:
            return R.string.localizable.keystoreAccessKeyNeedImportOrPasscode(preferredLanguages: Languages.preferred())
        case .userCancelled:
            return R.string.localizable.keystoreAccessKeyCancelled(preferredLanguages: Languages.preferred())
        }
    }
}
