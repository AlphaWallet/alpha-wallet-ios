// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

enum AssetImplicitAttributes: CaseIterable {
    case name
    case symbol
    case contractAddress
    case ownerAddress
    case tokenId

    var javaScriptName: String {
        switch self {
        case .name:
            return "name"
        case .symbol:
            return "symbol"
        case .contractAddress:
            return "contractAddress"
        case .ownerAddress:
            return "ownerAddress"
        case .tokenId:
            return "tokenId"
        }
    }

    func shouldInclude(forAddress address: String, isFungible: Bool) -> Bool {
        let isNativeCryptoCurrency = address.sameContract(as: Constants.nativeCryptoAddressInDatabase)
        switch self {
        case .name:
            return true
        case .symbol:
            return true
        case .contractAddress:
            return !isNativeCryptoCurrency
        case .ownerAddress:
            return true
        case .tokenId:
            return !isNativeCryptoCurrency && !isFungible
        }
    }
}
