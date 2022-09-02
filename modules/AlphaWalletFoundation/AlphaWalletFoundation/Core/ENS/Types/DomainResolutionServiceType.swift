//
//  DomainResolutionServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation 
import Combine
import AlphaWalletCore

public protocol DomainResolutionServiceType {
    func resolveAddress(string value: String) -> AnyPublisher<AlphaWallet.Address, PromiseError>
    func resolveEns(address: AlphaWallet.Address) -> AnyPublisher<EnsName, PromiseError>
    func resolveEnsAndBlockie(address: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
    func resolveAddressAndBlockie(string: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
}

public protocol CachebleAddressResolutionServiceType {
    func cachedAddressValue(for name: String) -> AlphaWallet.Address?
}

public protocol CachedEnsResolutionServiceType {
    func cachedEnsValue(for address: AlphaWallet.Address) -> String?
}
