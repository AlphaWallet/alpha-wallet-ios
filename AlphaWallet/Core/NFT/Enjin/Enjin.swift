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
    private let queue: DispatchQueue

    typealias EnjinBalances = [GetEnjinBalancesQuery.Data.EnjinBalance]
    typealias MappedEnjinBalances = [AlphaWallet.Address: EnjinBalances]

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func semiFungible(wallet: Wallet, server: RPCServer) -> Promise<EnjinSemiFungiblesToAddress> {
        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)

        guard Enjin.isServerSupported(key.server) else {
            return .value([:])
        }

        return fetchFromRemotePromise(wallet: wallet)
    }

    private func fetchFromRemotePromise(wallet: Wallet) -> Promise<EnjinSemiFungiblesToAddress> {
        return Promise<[AlphaWallet.Address: [GetEnjinBalancesQuery.Data.EnjinBalance]]> { seal in
            let offset = 1
            networkProvider.getEnjinBalances(forOwner: wallet.address, offset: offset) { result in
                switch result {
                case .success(let result):
                    seal.fulfill(result.balances)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }.then(on: queue, { [networkProvider] balances -> Promise<EnjinSemiFungiblesToAddress> in
            let ids = (balances[wallet.address] ?? []).compactMap { $0.token?.id }
            return networkProvider.getEnjinTokens(ids: ids, owner: wallet.address)
        })
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server {
        case .main:
            return true
        case .rinkeby, .kovan, .ropsten, .poa, .sokol, .classic, .callisto, .custom, .goerli, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi:
            return false
        }
    }
}
