//
//  AddressOrEnsResolution.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import PromiseKit
import AlphaWalletENS

enum AddressOrEnsResolution {
    case invalidInput
    case resolved(AddressOrEnsName?)

    var value: String? {
        switch self {
        case .invalidInput:
            return nil
        case .resolved(let optional):
            return optional?.stringValue
        }
    }
}

typealias BlockieAndAddressOrEnsResolution = (image: BlockiesImage?, resolution: AddressOrEnsResolution)

protocol DomainResolutionServiceType {
    func resolveAddress(string value: String) -> Promise<BlockieAndAddressOrEnsResolution>
    func resolveEns(address: AlphaWallet.Address) -> Promise<BlockieAndAddressOrEnsResolution>
}

protocol CachebleAddressResolutionServiceType {
    func cachedAddressValue(for name: String) -> AlphaWallet.Address?
}

protocol CachedEnsResolutionServiceType {
    func cachedEnsValue(for address: AlphaWallet.Address) -> String?
}
