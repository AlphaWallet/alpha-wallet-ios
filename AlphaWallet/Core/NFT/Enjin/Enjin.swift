//
//  Enjin.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.10.2021.
//

import Foundation
import Apollo
import PromiseKit

struct EnjinError: Error {
    var localizedDescription: String
}

typealias EnjinSemiFungiblesToAddress = [AlphaWallet.Address: [GetEnjinTokenQuery.Data.EnjinToken]]
typealias EnjinSemiFungiblesToTokenId = [String: GetEnjinTokenQuery.Data.EnjinToken]

final class Enjin {
    private lazy var networkProvider = EnjinNetworkProvider(queue: queue)
    private var cachedPromises: AtomicDictionary<AddressAndRPCServer, Promise<EnjinSemiFungiblesToAddress>> = .init()
    private let queue: DispatchQueue = DispatchQueue(label: "com.Enjin.UpdateQueue")
    typealias EnjinBalances = [GetEnjinBalancesQuery.Data.EnjinBalance]
    typealias MappedEnjinBalances = [AlphaWallet.Address: EnjinBalances]

    func semiFungible(wallet: Wallet, server: RPCServer) -> Promise<EnjinSemiFungiblesToAddress> {
        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)

        guard Enjin.isServerSupported(key.server) else {
            return .value([:])
        }

        return makeFetchPromise(for: key)
    }

    private func makeFetchPromise(for key: AddressAndRPCServer) -> Promise<EnjinSemiFungiblesToAddress> {
        if let promise = cachedPromises[key] {
            if promise.isResolved {
                let promise = fetchFromRemotePromise(key: key)
                cachedPromises[key] = promise

                return promise
            } else {
                return promise
            }
        } else {
            let promise = fetchFromRemotePromise(key: key)
            cachedPromises[key] = promise

            return promise
        }
    }

    private func fetchFromRemotePromise(key: AddressAndRPCServer) -> Promise<EnjinSemiFungiblesToAddress> {
        return Promise<[AlphaWallet.Address: [GetEnjinBalancesQuery.Data.EnjinBalance]]> { seal in
            let offset = 1
            networkProvider.getEnjinBalances(forOwner: key.address, offset: offset) { result in
                switch result {
                case .success(let result):
                    seal.fulfill(result.balances)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }.then(on: queue, { balances -> Promise<EnjinSemiFungiblesToAddress> in
            let ids = (balances[key.address] ?? []).compactMap { $0.token?.id }
            return self.networkProvider.getEnjinTokens(ids: ids, owner: key.address)
        }).ensure(on: queue, {
            self.cachedPromises[key] = .none
        })
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main:
            return true
        case .rinkeby, .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet:
            return false
        }
    }
}
