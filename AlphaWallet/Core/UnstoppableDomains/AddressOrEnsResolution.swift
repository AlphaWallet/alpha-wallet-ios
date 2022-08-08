//
//  AddressOrEnsResolution.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import Combine
import AlphaWalletCore

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
    func resolveAddress(string value: String) -> AnyPublisher<AlphaWallet.Address, PromiseError>
    func resolveEns(address: AlphaWallet.Address) -> AnyPublisher<EnsName, PromiseError>
    func resolveEnsAndBlockie(address: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
    func resolveAddressAndBlockie(string: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
}

protocol CachebleAddressResolutionServiceType {
    func cachedAddressValue(for name: String) -> AlphaWallet.Address?
}

protocol CachedEnsResolutionServiceType {
    func cachedEnsValue(for address: AlphaWallet.Address) -> String?
} 
