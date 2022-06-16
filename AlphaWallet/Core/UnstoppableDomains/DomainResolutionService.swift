//
//  DomainResolutionServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import Combine

class DomainResolutionService {
    let server: RPCServer = .forResolvingEns
    let blockiesGenerator: BlockiesGenerator
    private lazy var getEnsAddressResolver = ENSResolver(server: server)
    private lazy var unstoppableDomainsV2Resolver = UnstoppableDomainsV2Resolver(server: server)
    private lazy var ensReverseLookupResolver = ENSReverseResolver(server: server)

    init(blockiesGenerator: BlockiesGenerator) {
        self.blockiesGenerator = blockiesGenerator
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

        if let cached = services.compactMap({ $0.cachedAddressValue(forName: value) }).first {
            return resolveBlockieImage(addr: cached)
        }

        return getEnsAddressResolver
            .getENSAddressFromResolver(forName: value).publisher
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

        if let cached = services.compactMap({ $0.cachedEnsValue(forAddress: address) }).first {
            return resolveBlockieImage(ens: cached)
        }

        return ensReverseLookupResolver
            .getENSNameFromResolver(forAddress: address).publisher
            .catch { [unstoppableDomainsV2Resolver] _ -> AnyPublisher<String, PromiseError> in
                unstoppableDomainsV2Resolver.resolveDomain(address: address).publisher
                    .eraseToAnyPublisher()
            }.flatMap { ens -> AnyPublisher<BlockieAndAddressOrEnsResolution, PromiseError> in
                resolveBlockieImage(ens: ens)
            }.eraseToAnyPublisher()
    }
}
