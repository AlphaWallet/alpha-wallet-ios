//
//  DomainResolutionServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import PromiseKit
import Combine

class DomainResolutionService {
    let server: RPCServer = .forResolvingEns
    private let storage: EnsRecordsStorage
    private lazy var blockiesGenerator = BlockiesGenerator(storage: storage)

    init(storage: EnsRecordsStorage = sharedEnsRecordsStorage) {
        self.storage = storage
    }
}

extension DomainResolutionService: DomainResolutionServiceType {
    func resolveAddress(string value: String) -> Promise<BlockieAndAddressOrEnsResolution> {

        func resolveBlockieImage(addr: AlphaWallet.Address) -> Promise<BlockieAndAddressOrEnsResolution> {
            blockiesGenerator.promise(address: addr, ens: value)
                .map(on: .none, { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.address(addr)))
                }).recover(on: .none, { _ -> Promise<BlockieAndAddressOrEnsResolution> in
                    return .value((nil, .resolved(.address(addr))))
                })
        }

        let getEnsAddressResolver = EnsResolver(server: server, storage: storage)
        let unstoppableDomainsV2Resolver = UnstoppableDomainsV2Resolver(server: server, storage: storage)

        let services: [CachebleAddressResolutionServiceType] = [
            getEnsAddressResolver,
            unstoppableDomainsV2Resolver
        ]

        if let cached = services.compactMap({ $0.cachedAddressValue(for: value) }).first {
            return resolveBlockieImage(addr: cached)
        }

        return getEnsAddressResolver.getENSAddressFromResolver(for: value)
            .recover(on: .none, { _ -> Promise<AlphaWallet.Address> in
                unstoppableDomainsV2Resolver.resolveAddress(forName: value)
            }).then(on: .none, { addr -> Promise<BlockieAndAddressOrEnsResolution> in
                resolveBlockieImage(addr: addr)
            })
    }

    func resolveEns(address: AlphaWallet.Address) -> Promise<BlockieAndAddressOrEnsResolution> {

        func resolveBlockieImage(ens: String) -> Promise<BlockieAndAddressOrEnsResolution> {
            blockiesGenerator.promise(address: address, ens: ens)
                .map(on: .none, { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.ensName(ens)))
                }).recover(on: .none, { _ -> Promise<BlockieAndAddressOrEnsResolution> in
                    return .value((nil, .resolved(.ensName(ens))))
                })
        }

        let ensReverseLookupResolver = EnsReverseResolver(server: server, storage: storage)
        let unstoppableDomainsV2Resolver = UnstoppableDomainsV2Resolver(server: server, storage: storage)

        let services: [CachedEnsResolutionServiceType] = [
            ensReverseLookupResolver,
            unstoppableDomainsV2Resolver
        ]

        if let cached = services.compactMap({ $0.cachedEnsValue(for: address) }).first {
            return resolveBlockieImage(ens: cached)
        }

        return ensReverseLookupResolver
            .getENSNameFromResolver(for: address)
            .recover(on: .none, { _ -> Promise<String> in
                unstoppableDomainsV2Resolver.resolveDomain(address: address)
            }).then(on: .none, { ens -> Promise<BlockieAndAddressOrEnsResolution> in
                resolveBlockieImage(ens: ens)
            })
    }
}
