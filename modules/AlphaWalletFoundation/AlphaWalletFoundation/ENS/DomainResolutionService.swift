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
    public func resolveAddress(string value: String) -> AnyPublisher<AlphaWallet.Address, PromiseError> {
        let services: [CachedDomainNameResolutionServiceType] = [
            getEnsAddressResolver,
            unstoppableDomainsResolver
        ]

        if let cached = services.compactMap({ $0.cachedAddress(for: value) }).first {
            return .just(cached)
        }

        return Just(value)
            .setFailureType(to: SmartContractError.self)
            .flatMap { [getEnsAddressResolver] value in
                getEnsAddressResolver.getENSAddressFromResolver(for: value)
            }.catch { [unstoppableDomainsResolver] _ -> AnyPublisher<AlphaWallet.Address, PromiseError> in
                unstoppableDomainsResolver.resolveAddress(forName: value)
            }.receive(on: RunLoop.main)//We want to be sure it's on main
            .eraseToAnyPublisher()
    }

    public func resolveEnsAndBlockie(address: AlphaWallet.Address, server actualServer: RPCServer) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        func getBlockieImage(for ens: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
            return blockiesGenerator.getBlockieOrEnsAvatarImage(address: address, ens: ens)
                .map { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.domainName(ens)))
                }.catch { _ -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> in
                    return .just((nil, .resolved(.domainName(ens))))
                }.eraseToAnyPublisher()
        }

        return reverseResolveDomainName(address: address, server: actualServer)
            .flatMap { getBlockieImage(for: $0) }
            .eraseToAnyPublisher()
    }

    public func resolveAddressAndBlockie(string: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
        func getBlockieImage(for addr: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
            return blockiesGenerator.getBlockieOrEnsAvatarImage(address: addr, ens: string)
                .map { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.address(addr)))
                }.catch { _ -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> in
                    return .just((nil, .resolved(.address(addr))))
                }.eraseToAnyPublisher()
        }

        return resolveAddress(string: string)
            .flatMap { getBlockieImage(for: $0) }
            .eraseToAnyPublisher()
    }

    public func reverseResolveDomainName(address: AlphaWallet.Address, server actualServer: RPCServer) -> AnyPublisher<DomainName, PromiseError> {
        let services: [CachedDomainNameReverseResolutionServiceType] = [
            ensReverseLookupResolver,
            unstoppableDomainsResolver
        ]

        if let cached = services.compactMap({ $0.cachedDomainName(for: address) }).first {
            return .just(cached)
        }

        return Just(address)
            .setFailureType(to: SmartContractError.self)
            .flatMap { [ensReverseLookupResolver] address in
                ensReverseLookupResolver.getENSNameFromResolver(for: address)
            }.catch { [unstoppableDomainsResolver] _ -> AnyPublisher<String, PromiseError> in
                unstoppableDomainsResolver.resolveDomain(address: address, server: actualServer)
            }.receive(on: RunLoop.main)//We want to be sure it's on main
            .eraseToAnyPublisher()
    }
}
