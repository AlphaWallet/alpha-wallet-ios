// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

extension DecryptError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPassword:
            //Strings don't appear to be shown in the UI
            return "Invalid Password"
        case .invalidCipher:
            return "Invalid Cipher"
        case .unsupportedCipher:
            return "Unsupported Cipher"
        case .unsupportedKDF:
            return "Unsupported KDF"
        }
    }
}
