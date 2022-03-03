//
//  TokenObjectFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2022.
//

import Foundation
import PromiseKit

protocol TokenObjectFetcher: NSObjectProtocol {
    func fetchTokenObject(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool) -> Promise<SingleChainTokensAutodetector.AddTokenObjectOperation>
}

class SingleChainTokenObjectFetcher: NSObject, TokenObjectFetcher {

    private let account: Wallet
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

    init(account: Wallet, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.account = account
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    } 

    func fetchTokenObject(for contract: AlphaWallet.Address, onlyIfThereIsABalance: Bool = false) -> Promise<SingleChainTokensAutodetector.AddTokenObjectOperation> {
        let server = server
        let detector = ContractDataDetector(address: contract, account: account, server: server, assetDefinitionStore: assetDefinitionStore)
        return Promise { seal in
            detector.fetch { data in
                switch data {
                case .name, .symbol, .balance, .decimals:
                    break
                case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                    guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !balance.isEmpty) else { break }
                    let token = ERCToken(
                            contract: contract,
                            server: server,
                            name: name,
                            symbol: symbol,
                            decimals: 0,
                            type: tokenType,
                            balance: balance
                    )

                    seal.fulfill(.ercToken(token))
                case .fungibleTokenComplete(let name, let symbol, let decimals):
                    seal.fulfill(.fungibleTokenComplete(name: name, symbol: symbol, decimals: decimals, contract: contract, server: server, onlyIfThereIsABalance: onlyIfThereIsABalance))
                case .delegateTokenComplete:
                    seal.fulfill(.delegateContracts([DelegateContract(contractAddress: contract, server: server)]))
                case .failed(let networkReachable):
                    if let networkReachable = networkReachable, networkReachable {
                        seal.fulfill(.deletedContracts([DeletedContract(contractAddress: contract, server: server)]))
                    } else {
                        seal.fulfill(.none)
                    }
                }
            }
        }
    }
}
