//
//  DomainResolutionServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import Combine
import AlphaWalletENS
import AlphaWalletCore

public class DomainResolutionService {
    private let storage: DomainNameRecordsStorage
    private let blockiesGenerator: BlockiesGenerator
    private lazy var getEnsAddressResolver = EnsResolver(storage: storage, blockchainProvider: blockchainProvider)
    private lazy var unstoppableDomainsResolver = UnstoppableDomainsResolver(fallbackServer: blockchainProvider.server, storage: storage, networkService: networkService)
    private lazy var ensReverseLookupResolver = EnsReverseResolver(storage: storage, blockchainProvider: blockchainProvider)
    private let networkService: NetworkService
    private let blockchainProvider: BlockchainProvider

    public init(blockiesGenerator: BlockiesGenerator, storage: DomainNameRecordsStorage, networkService: NetworkService, blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.blockiesGenerator = blockiesGenerator
        self.storage = storage
        self.networkService = networkService
    }
}

extension DomainResolutionService: DomainNameResolutionServiceType {
    public func resolveAddress(string value: String) async throws -> AlphaWallet.Address {
        let services: [CachedDomainNameResolutionServiceType] = [
            getEnsAddressResolver,
            unstoppableDomainsResolver
        ]

        if let cached = await services.asyncCompactMap({ await $0.cachedAddress(for: value) }).first {
            return cached
        }

        do {
            return try await getEnsAddressResolver.getENSAddressFromResolver(for: value)
        } catch {
            return try await unstoppableDomainsResolver.resolveAddress(forName: value)
        }
    }

    public func resolveEnsAndBlockie(address: AlphaWallet.Address, server actualServer: RPCServer) async throws -> BlockieAndAddressOrEnsResolution {
        let ens = try await reverseResolveDomainName(address: address, server: actualServer)
        do {
            let image = try await blockiesGenerator.getBlockieOrEnsAvatarImage(address: address, ens: ens)
            return (image, .resolved(.domainName(ens)))
        } catch {
            return (nil, .resolved(.domainName(ens)))
        }
    }

    public func resolveAddressAndBlockie(string: String) async throws -> BlockieAndAddressOrEnsResolution {
        let address = try await resolveAddress(string: string)
        do {
            let image = try await blockiesGenerator.getBlockieOrEnsAvatarImage(address: address, ens: string)
            return (image, .resolved(.address(address)))
        } catch {
            return (nil, .resolved(.address(address)))
        }
    }

    public func reverseResolveDomainName(address: AlphaWallet.Address, server actualServer: RPCServer) async throws -> DomainName {
        let services: [CachedDomainNameReverseResolutionServiceType] = [
            ensReverseLookupResolver,
            unstoppableDomainsResolver
        ]

        if let cached = await services.asyncCompactMap({ await $0.cachedDomainName(for: address) }).first {
            return cached
        }

        do {
            return try await ensReverseLookupResolver.getENSNameFromResolver(for: address)
        } catch {
            return try await unstoppableDomainsResolver.resolveDomain(address: address, server: actualServer)
        }
    }
}
