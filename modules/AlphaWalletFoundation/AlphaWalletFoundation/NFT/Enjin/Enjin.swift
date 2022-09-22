//
//  Enjin.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.10.2021.
//

import Foundation
import Apollo
import PromiseKit

public struct EnjinError: Error {
    var localizedDescription: String
}

public typealias EnjinAddressesToSemiFungibles = [AlphaWallet.Address: [GetEnjinTokenQuery.Data.EnjinToken]]
public typealias EnjinTokenIdsToSemiFungibles = [String: GetEnjinTokenQuery.Data.EnjinToken]

public final class Enjin {
    private lazy var networkProvider = EnjinNetworkProvider(queue: queue)
    private let queue: DispatchQueue

    public typealias EnjinBalances = [GetEnjinBalancesQuery.Data.EnjinBalance]
    public typealias MappedEnjinBalances = [AlphaWallet.Address: EnjinBalances]

    public init(queue: DispatchQueue) {
        self.queue = queue
    }

    public func semiFungible(wallet: Wallet, server: RPCServer) -> Promise<EnjinAddressesToSemiFungibles> {
        let key: AddressAndRPCServer = .init(address: wallet.address, server: server)

        guard Enjin.isServerSupported(key.server) else {
            return .value([:])
        }

        return fetchFromRemotePromise(wallet: wallet)
    }

    private func fetchFromRemotePromise(wallet: Wallet) -> Promise<EnjinAddressesToSemiFungibles> {
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
        }.then(on: queue, { [networkProvider] balances -> Promise<EnjinAddressesToSemiFungibles> in
            let ids = (balances[wallet.address] ?? []).compactMap { $0.token?.id }
            return networkProvider.getEnjinTokens(ids: ids, owner: wallet.address)
        })
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server.serverWithEnhancedSupport {
        case .main:
            return true
        case .xDai, .candle, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            return false
        }
    }
}
