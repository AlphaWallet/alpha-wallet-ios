// Copyright © 2023 Stormbird PTE. LTD.

public enum HardwareWalletError: Error {
    case failedToSign(wrappedError: Error)
    //TODO should this be create or import? Or both?
    case failedToImportSeed(wrappedError: Error)
    case failedToWipe(wrappedError: Error)
    case failedToGetPublicKey(wrappedError: Error)
    case userCancelled(wrappedError: Error)
}

public extension Error {
    var isCancelledBChainRequest: Bool {
        if let error = self as? HardwareWalletError, case .userCancelled = error {
            return true
        } else {
            return false
        }
    }
}
