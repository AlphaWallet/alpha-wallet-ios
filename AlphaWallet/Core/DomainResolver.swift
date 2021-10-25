//
//  DomainResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.11.2020.
//

import Foundation
import UnstoppableDomainsResolution
import PromiseKit
import web3swift

extension Resolution {
    convenience init?(server: RPCServer) {
        guard let networkName = server.unstoppableDomainLookupName else { return nil }
        try? self.init(providerUrl: server.rpcURL.absoluteString, network: networkName)
    }
}

class DomainResolver {

    private struct ENSLookupKey: Hashable {
        let name: String
        let server: RPCServer
    }

    private enum AnyError: Error {
        case failureToResolve
        case invalidAddress
        case invalidInput
    }

    private let server: RPCServer
    private static var cache: [ENSLookupKey: AlphaWallet.Address] = [:]
    private var resolution: Resolution?
    private let ticker: String = "eth" //Not sure what `ticker` do we need to use here

    init(server: RPCServer) {
        self.server = server
        self.resolution = Resolution(server: server)
    }

    func resolveAddress(_ input: String) -> Promise<AlphaWallet.Address> {
        //if already an address, send back the address
        if let value = AlphaWallet.Address(string: input) {
            return .value(value)
        }

        let node = input.lowercased().nameHash
        if let value = cachedResult(forNode: node) {
            return .value(value)
        }

        return DASNameLookupCoordinator()
            .resolve(rpcURL: .forResolvingDAS, value: input)
            .recover { _ -> Promise<AlphaWallet.Address> in
                self.domainResolution(domain: input)
            }.get { address in
                self.cache(forNode: node, result: address)
            }
    }

    private func domainResolution(domain: String) -> Promise<AlphaWallet.Address> {
        guard let resolution = resolution else { return .init(error: AnyError.invalidAddress) }

        return Promise { seal in
            resolution.addr(domain: domain, ticker: self.ticker) { result in
                switch result {
                case .success(let value):
                    if let address = AlphaWallet.Address(string: value) {

                        seal.fulfill(address)
                    } else {
                        seal.reject(AnyError.invalidAddress)
                    }
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    private func cachedResult(forNode node: String) -> AlphaWallet.Address? {
        return DomainResolver.cache[ENSLookupKey(name: node, server: server)]
    }

    private func cache(forNode node: String, result: AlphaWallet.Address) {
        DomainResolver.cache[ENSLookupKey(name: node, server: server)] = result
    }
}

extension GetENSAddressCoordinator {

    func getENSAddressFromResolverPromise(value: String) -> Promise<AlphaWallet.Address> {
        return Promise { seal in
            GetENSAddressCoordinator(server: server).getENSAddressFromResolver(for: value) { result in
                switch result {
                case .success(let address):
                    seal.fulfill(address)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}

fileprivate extension RPCServer {
    //These strings need to match what is used by UnstoppableDomains's code (look up where it's used)
    var unstoppableDomainLookupName: String? {
        switch self {
        case .main: return "mainnet"
        case .kovan: return "kovan"
        case .ropsten: return "ropsten"
        case .rinkeby: return "rinkeby"
        case .poa, .sokol, .classic, .callisto, .xDai, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .custom, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .palm, .palmTestnet:
            return nil
        }
    }
}
