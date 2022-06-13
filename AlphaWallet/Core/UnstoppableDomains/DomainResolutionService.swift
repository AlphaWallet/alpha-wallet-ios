//
//  DomainResolutionServiceType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import PromiseKit

class DomainResolutionService {
    let server: RPCServer = .forResolvingEns
    let blockiesGenerator: BlockiesGenerator

    init(blockiesGenerator: BlockiesGenerator) {
        self.blockiesGenerator = blockiesGenerator
    }
}

extension DomainResolutionService: DomainResolutionServiceType {
    func resolveAddress(string value: String) -> Promise<BlockieAndAddressOrEnsResolution> {

        func resolveBlockieImage(addr: AlphaWallet.Address) -> Promise<BlockieAndAddressOrEnsResolution> {
            blockiesGenerator
                .promise(address: addr, ens: value)
                .map { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.address(addr)))
                }.recover { _ -> Promise<BlockieAndAddressOrEnsResolution> in
                    return .value((nil, .resolved(.address(addr))))
                }
        }

        let getEnsAddressCoordinator = ENSResolver(server: server)
        let unstoppableDomainsV2Resolver = UnstoppableDomainsV2Resolver(server: server)

        let services: [CachebleAddressResolutionServiceType] = [
            getEnsAddressCoordinator,
            unstoppableDomainsV2Resolver
        ]

        if let cached = services.compactMap({ $0.cachedAddressValue(forName: value) }).first {
            return resolveBlockieImage(addr: cached)
        }

        return getEnsAddressCoordinator
            .getENSAddressFromResolver(forName: value)
            .recover { _ -> Promise<AlphaWallet.Address> in
                unstoppableDomainsV2Resolver.resolveAddress(forName: value)
            }.then { addr -> Promise<BlockieAndAddressOrEnsResolution> in
                resolveBlockieImage(addr: addr)
            }
    }

    func resolveEns(address: AlphaWallet.Address) -> Promise<BlockieAndAddressOrEnsResolution> {

        func resolveBlockieImage(ens: String) -> Promise<BlockieAndAddressOrEnsResolution> {
            blockiesGenerator
                .promise(address: address, ens: ens)
                .map { image -> BlockieAndAddressOrEnsResolution in
                    return (image, .resolved(.ensName(ens)))
                }.recover { _ -> Promise<BlockieAndAddressOrEnsResolution> in
                    return .value((nil, .resolved(.ensName(ens))))
                }
        }

        let ensReverseLookupCoordinator = ENSReverseResolver(server: server)
        let unstoppableDomainsV2Resolver = UnstoppableDomainsV2Resolver(server: server)

        let services: [CachedEnsResolutionServiceType] = [
            ensReverseLookupCoordinator,
            unstoppableDomainsV2Resolver
        ]

        if let cached = services.compactMap({ $0.cachedEnsValue(forAddress: address) }).first {
            return resolveBlockieImage(ens: cached)
        }

        return ensReverseLookupCoordinator
            .getENSNameFromResolver(forAddress: address)
            .recover { _ -> Promise<String> in
                unstoppableDomainsV2Resolver
                    .resolveDomain(address: address)
            }
            .then { ens -> Promise<BlockieAndAddressOrEnsResolution> in
                resolveBlockieImage(ens: ens)
            }
    }
}
