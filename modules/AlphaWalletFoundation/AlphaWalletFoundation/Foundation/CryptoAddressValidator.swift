// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum AddressValidatorType {
    case ethereum

    var addressLength: Int {
        switch self {
        case .ethereum: return 42
        }
    }
}

public struct CryptoAddressValidator {
    //TODO do we still need this?
    public static func isValidAddress(_ value: String?, type: AddressValidatorType = .ethereum) -> Bool {
        guard value?.count == type.addressLength else {
            return false
        }
        return true
    }
}
