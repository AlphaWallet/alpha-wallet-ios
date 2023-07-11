//
//  DomainResolutionServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletENS

public protocol DomainNameResolutionServiceType {
    func resolveAddress(string value: String) -> AnyPublisher<AlphaWallet.Address, PromiseError>
    func reverseResolveDomainName(address: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<DomainName, PromiseError>
    //TODO does UnstoppableDomains support blockies the same way as ENS?
    func resolveEnsAndBlockie(address: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
    func resolveAddressAndBlockie(string: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError>
}

public protocol CachedDomainNameResolutionServiceType {
    func cachedAddress(for name: String) -> AlphaWallet.Address?
}

public protocol CachedDomainNameReverseResolutionServiceType {
    func cachedDomainName(for address: AlphaWallet.Address) -> String?
}
