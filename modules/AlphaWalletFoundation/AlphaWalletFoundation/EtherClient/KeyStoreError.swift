// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum KeystoreError: Error {
    case failedToDeleteAccount
    case failedToDecryptKey
    case failedToImport(Error)
    case duplicateAccount
    case failedToSignTransaction
    case failedToEncodeRLP
    case failedToCreateWallet
    case failedToImportPrivateKey
    case failedToParseJSON
    case accountNotFound
    case failedToSignMessage
    case signDataIsEmpty
    case failedToExportPrivateKey
    case failedToExportSeed
    case accountMayNeedImportingAgainOrEnablePasscode
    case userCancelled
}
