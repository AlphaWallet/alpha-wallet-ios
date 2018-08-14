// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore

///Use this enum to "mark" where we do special handling for CryptoKitty instead of accessing the crypto kitty contract access directly
///If there are other special casing for CryptoKitty that doesn't fit this model, create another enum type (not case)
enum CryptoKittyHandling {
    case cryptoKitty
    case otherNonFungibleToken

    init(contract: String) {
        self = {
            if contract.sameContract(as: Constants.cryptoKittiesContractAddress) {
                return .cryptoKitty
            } else {
                return .otherNonFungibleToken
            }
        }()
    }

    init(address: Address) {
        self.init(contract: address.eip55String)
    }
}
