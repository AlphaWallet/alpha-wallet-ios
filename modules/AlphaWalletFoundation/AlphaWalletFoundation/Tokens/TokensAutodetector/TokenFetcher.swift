//
//  TokenFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import PromiseKit

public protocol TokenFetcher: NSObjectProtocol {
    func fetchTokenOrContract(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool) -> Promise<TokenOrContract>
}

public class SingleChainTokenFetcher: NSObject, TokenFetcher {
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let queue = DispatchQueue(label: "org.alphawallet.swift.singleChainTokenFetcher")
    private var inFlightPromises: [String: Promise<TokenOrContract>] = [:]
    private let session: WalletSession

    public init(session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger) {
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
    }

    public func fetchTokenOrContract(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> Promise<TokenOrContract> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, session, assetDefinitionStore, analytics] contract -> Promise<TokenOrContract> in
            let key = "\(contract.hashValue)-\(onlyIfThereIsABalance)"

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let server = session.server
                let detector = ContractDataDetector(address: contract, account: session.account, server: server, assetDefinitionStore: assetDefinitionStore, analytics: analytics)
                let promise = Promise<TokenOrContract> { seal in
                    detector.fetch { data in
                        switch data {
                        case .name, .symbol, .balance, .decimals:
                            break
                        case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                            guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !balance.isEmpty) else {
                                seal.fulfill(.none)
                                break
                            }
                            let ercToken = ERCToken(contract: contract, server: server, name: name, symbol: symbol, decimals: 0, type: tokenType, balance: balance)

                            seal.fulfill(.nonFungibleToken(ercToken))
                        case .fungibleTokenComplete(let name, let symbol, let decimals):
                            seal.fulfill(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals, contract: contract, server: server, onlyIfThereIsABalance: onlyIfThereIsABalance))
                        case .delegateTokenComplete:
                            seal.fulfill(.delegateContracts([AddressAndRPCServer(address: contract, server: server)]))
                        case .failed(let networkReachable):
                            if let networkReachable = networkReachable, networkReachable {
                                seal.fulfill(.deletedContracts([AddressAndRPCServer(address: contract, server: server)]))
                            } else {
                                seal.fulfill(.none)
                            }
                        }
                    }
                }.ensure(on: queue, {
                    self?.inFlightPromises[key] = nil
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}
