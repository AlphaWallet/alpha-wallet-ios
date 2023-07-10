// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

public enum AssetImplicitAttributes: String, CaseIterable {
    case label
    case symbol
    case contractAddress
    case ownerAddress
    case tokenId

    public var javaScriptName: String {
        switch self {
        case .label:
            return "label"
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

    public func shouldInclude(forAddress address: AlphaWallet.Address, isFungible: Bool) -> Bool {
        let isNativeCryptoCurrency = address == Constants.nativeCryptoAddressInDatabase
        switch self {
        case .label:
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
