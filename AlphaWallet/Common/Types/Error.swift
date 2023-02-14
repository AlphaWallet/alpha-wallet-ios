// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import AlphaWalletCore

extension KeystoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToDeleteAccount:
            return R.string.localizable.accountsDeleteErrorFailedToDeleteAccount()
        case .failedToDecryptKey:
            return R.string.localizable.accountsErrorFailedToDecryptKey()
        case .failedToImport(let error):
            return error.localizedDescription
        case .duplicateAccount:
            return R.string.localizable.accountsErrorDuplicateAccount()
        case .failedToSignTransaction:
            return R.string.localizable.accountsErrorFailedToSignTransaction()
        case .failedToCreateWallet:
            return R.string.localizable.accountsErrorFailedToCreateWallet()
        case .failedToImportPrivateKey:
            return R.string.localizable.accountsErrorFailedToImportPrivateKey()
        case .failedToParseJSON:
            return R.string.localizable.accountsErrorFailedToParseJSON()
        case .accountNotFound:
            return R.string.localizable.accountsErrorAccountNotFound()
        case .failedToSignMessage:
            return R.string.localizable.accountsErrorFailedToSignMessage()
        case .failedToExportPrivateKey:
            return R.string.localizable.accountsErrorFailedToExportPrivateKey()
        case .failedToExportSeed:
            return R.string.localizable.accountsErrorFailedToExportSeed()
        case .accountMayNeedImportingAgainOrEnablePasscode:
            return R.string.localizable.keystoreAccessKeyNeedImportOrPasscode()
        case .userCancelled:
            return R.string.localizable.keystoreAccessKeyCancelled()
        case .signDataIsEmpty:
            return R.string.localizable.accountsErrorFailedToSignEmptyMessage()
        case .failedToEncodeRLP:
            return R.string.localizable.accountsErrorFailedToSignTransaction()
        }
    }
}

extension Error {
    public var code: Int { return (self as NSError).code }
    public var domain: String { return (self as NSError).domain }
}

extension PromiseError: LocalizedError {
    public var errorDescription: String? {
        return embedded.localizedDescription
    }
}

extension SessionTaskError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionError(let error):
            return error.localizedDescription
        case .requestError(let error):
            return error.localizedDescription
        case .responseError(let error):
            return error.localizedDescription
        }
    }
}

extension AnyCAIP10AccountProvidable.CAIP10AccountProvidableError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unavailableToBuildBlockchain:
            return "Unavailable To Build Blockchain"
        case .chainNotSupportedOrNotEnabled:
            return "Chain Not Supported Or Not Enabled"
        case .emptyNamespaces:
            return "Empty Namespaces"
        case .eip155NotFound:
            return "Eip155 Not Found"
        }
    }
}
