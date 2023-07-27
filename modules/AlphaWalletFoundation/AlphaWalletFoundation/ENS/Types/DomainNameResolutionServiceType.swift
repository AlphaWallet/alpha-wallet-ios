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
    func resolveAddress(string value: String) async throws -> AlphaWallet.Address
    func reverseResolveDomainName(address: AlphaWallet.Address, server: RPCServer) async throws -> DomainName
    //TODO does UnstoppableDomains support blockies the same way as ENS?
    func resolveEnsAndBlockie(address: AlphaWallet.Address, server actualServer: RPCServer) async throws -> BlockieAndAddressOrEnsResolution
    func resolveAddressAndBlockie(string: String) async throws -> BlockieAndAddressOrEnsResolution
}

public protocol CachedDomainNameResolutionServiceType {
    func cachedAddress(for name: String) async -> AlphaWallet.Address?
}

public protocol CachedDomainNameReverseResolutionServiceType {
    func cachedDomainName(for address: AlphaWallet.Address) async -> String?
}
