// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum AddressValidatorType {
    case ethereum

    var addressLength: Int {
        switch self {
        case .ethereum: return 42
        }
    }
}

struct CryptoAddressValidator {
    //TODO do we still need this?
    static func isValidAddress(_ value: String?, type: AddressValidatorType = .ethereum) -> Bool {
        guard value?.count == type.addressLength else {
            return false
        }
        return true
    }
}
