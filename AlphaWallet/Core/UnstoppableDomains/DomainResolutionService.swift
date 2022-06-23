//
//  DomainResolutionServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import Combine

class DomainResolutionService {
    private let storage: EnsRecordsStorage
    private let blockiesGenerator: BlockiesGenerator
    private lazy var getEnsAddressResolver = EnsResolver(server: server, storage: storage)
    private lazy var unstoppableDomainsV2Resolver = UnstoppableDomainsV2Resolver(server: server, storage: storage)
    private lazy var ensReverseLookupResolver = EnsReverseResolver(server: server, storage: storage)

    let server: RPCServer = .forResolvingEns

    init(blockiesGenerator: BlockiesGenerator, storage: EnsRecordsStorage) {
        self.blockiesGenerator = blockiesGenerator
        self.storage = storage
    }
}

extension DomainResolutionService: DomainResolutionServiceType {
    func resolveAddress(string value: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {

        func resolveBlockieImage(addr: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
            blockiesGenerator
                .promise(address: addr, ens: value).publisher
                .map { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.address(addr)))
                }.catch { _ -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> in
                    Just((nil, .resolved(.address(addr)))).setFailureType(to: PromiseError.self).eraseToAnyPublisher()
                }.eraseToAnyPublisher()
        }

        let services: [CachebleAddressResolutionServiceType] = [
            getEnsAddressResolver,
            unstoppableDomainsV2Resolver
        ]

        if let cached = services.compactMap({ $0.cachedAddressValue(for: value) }).first {
            return resolveBlockieImage(addr: cached)
        }

        return getEnsAddressResolver
            .getENSAddressFromResolver(for: value).publisher
            .catch { _ -> AnyPublisher<AlphaWallet.Address, PromiseError> in
                self.unstoppableDomainsV2Resolver.resolveAddress(forName: value).publisher
                    .eraseToAnyPublisher()
            }.flatMap { addr -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> in
                resolveBlockieImage(addr: addr)
            }.eraseToAnyPublisher()
    }

    func resolveEns(address: AlphaWallet.Address) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {

        func resolveBlockieImage(ens: String) -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> {
            blockiesGenerator
                .promise(address: address, ens: ens).publisher
                .map { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.ensName(ens)))
                }.catch { _ -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> in
                    return Just((nil, .resolved(.ensName(ens)))).setFailureType(to: PromiseError.self).eraseToAnyPublisher()
                }.eraseToAnyPublisher()
        }

        let services: [CachedEnsResolutionServiceType] = [
            ensReverseLookupResolver,
            unstoppableDomainsV2Resolver
        ]

        if let cached = services.compactMap({ $0.cachedEnsValue(for: address) }).first {
            return resolveBlockieImage(ens: cached)
        }

        return ensReverseLookupResolver
            .getENSNameFromResolver(for: address).publisher
            .catch { [unstoppableDomainsV2Resolver] _ -> AnyPublisher<String, PromiseError> in
                unstoppableDomainsV2Resolver.resolveDomain(address: address).publisher
                    .eraseToAnyPublisher()
            }.flatMap { ens -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> in
                resolveBlockieImage(ens: ens)
            }.eraseToAnyPublisher()
    }
}
