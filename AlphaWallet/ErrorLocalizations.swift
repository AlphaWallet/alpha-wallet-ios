// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletHardwareWallet

extension HardwareWalletError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToSign(let wrappedError):
            return R.string.localizable.hardwareWalletFailedToSign(wrappedError.localizedDescription)
        case .failedToImportSeed(let wrappedError):
            return R.string.localizable.hardwareWalletFailedToImportSeed(wrappedError.localizedDescription)
        case .failedToWipe(let wrappedError):
            return R.string.localizable.hardwareWalletFailedToWipe(wrappedError.localizedDescription)
        case .failedToGetPublicKey(let wrappedError):
            return R.string.localizable.hardwareWalletFailedToGetPublicKey(wrappedError.localizedDescription)
        case .userCancelled(let wrappedError):
            return "\(R.string.localizable.error()): \(wrappedError.localizedDescription)"
        }
    }
}