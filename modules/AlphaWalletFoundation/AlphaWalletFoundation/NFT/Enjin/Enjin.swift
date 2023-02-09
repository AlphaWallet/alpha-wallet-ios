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
    private lazy var networkProvider = EnjinNetworkProvider()
    private let queue = DispatchQueue(label: "org.alphawallet.swift.enjin")
    private var inFlightPromises: [String: Promise<EnjinAddressesToSemiFungibles>] = [:]
    private let server: RPCServer
    public typealias EnjinBalances = [GetEnjinBalancesQuery.Data.EnjinBalance]
    public typealias MappedEnjinBalances = [AlphaWallet.Address: EnjinBalances]

    public init(server: RPCServer) {
        self.server = server
    }

    public func semiFungible(wallet: Wallet) -> Promise<EnjinAddressesToSemiFungibles> {
        firstly {
            .value(wallet)
        }.then(on: queue, { [weak self, queue, networkProvider, server] wallet -> Promise<EnjinAddressesToSemiFungibles> in
            guard Enjin.isServerSupported(server) else { return .value([:]) }

            let key = "\(wallet.address.eip55String)-\(server.chainID)"
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                //NOTE: Make sure Apollo get called on main queue, looks like its not threadsafe, (accessing to interceptors on background queue causes bad access)
                let promise = firstly {
                    .value(wallet)
                }.then { wallet in
                    networkProvider.getEnjinBalances(forOwner: wallet.address, offset: 1)
                }.then { [networkProvider] balances -> Promise<EnjinAddressesToSemiFungibles> in
                    let ids = (balances[wallet.address] ?? []).compactMap { $0.token?.id }
                    return networkProvider.getEnjinTokens(ids: ids, owner: wallet.address)
                }.ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }

    static func isServerSupported(_ server: RPCServer) -> Bool {
        switch server.serverWithEnhancedSupport {
        case .main:
            return true
        case .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            return false
        }
    }
}
