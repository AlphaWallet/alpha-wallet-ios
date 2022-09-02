//
//  NonFungibleErc1155JsonBalanceFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.07.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletOpenSea
import BigInt
import PromiseKit
import SwiftyJSON

//TODO: think about the name, remove queue later, replace with any publisher
public class NonFungibleErc1155JsonBalanceFetcher {
    typealias TokenIdMetaData = (contract: AlphaWallet.Address, tokenId: BigUInt, jsonAndItsSource: NonFungibleBalanceAndItsSource<JsonString>)

    private let nonFungibleJsonBalanceFetcher: NonFungibleJsonBalanceFetcher
    private let erc1155TokenIdsFetcher: Erc1155TokenIdsFetcher
    private let erc1155BalanceFetcher: Erc1155BalanceFetcher
    private let account: Wallet
    private let queue: DispatchQueue
    private let server: RPCServer
    private let tokensService: TokenProvidable & TokenAddable
    private let analytics: AnalyticsLogger
    private let assetDefinitionStore: AssetDefinitionStore

    public init(assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, tokensService: TokenProvidable & TokenAddable, account: Wallet, server: RPCServer, erc1155TokenIdsFetcher: Erc1155TokenIdsFetcher, nonFungibleJsonBalanceFetcher: NonFungibleJsonBalanceFetcher, erc1155BalanceFetcher: Erc1155BalanceFetcher, queue: DispatchQueue) {
        self.assetDefinitionStore = assetDefinitionStore
        self.account = account
        self.server = server
        self.erc1155TokenIdsFetcher = erc1155TokenIdsFetcher
        self.queue = queue
        self.tokensService = tokensService
        self.nonFungibleJsonBalanceFetcher = nonFungibleJsonBalanceFetcher
        self.analytics = analytics
        self.erc1155BalanceFetcher = erc1155BalanceFetcher
    }

    public func fetchErc1155NonFungibleJsons(enjinTokens: EnjinTokenIdsToSemiFungibles) -> Promise<[AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NonFungibleFromTokenUri>]]> {
        guard Features.default.isAvailable(.isErc1155Enabled) else { return .init(error: PMKError.cancelled) }
        //Local copies so we don't access the wrong ones during async operation

        return firstly {
            erc1155TokenIdsFetcher.detectContractsAndTokenIds()
        }.then(on: queue, { contractsAndTokenIds in
            self.addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: contractsAndTokenIds.tokens)
        }).then(on: queue, { contractsAndTokenIds -> Promise<(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokenIdMetaDatas: [TokenIdMetaData])> in
                self._fetchErc1155NonFungibleJsons(contractsAndTokenIds: contractsAndTokenIds, enjinTokens: enjinTokens)
                    .map { (contractsAndTokenIds: contractsAndTokenIds, tokenIdMetaDatas: $0) }
        }).then(on: queue, { [erc1155BalanceFetcher, queue] (contractsAndTokenIds, tokenIdMetaDatas) -> Promise<[AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NonFungibleFromTokenUri>]]> in

            let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractsAndTokenIds
                .mapValues { tokenIds -> [BigInt] in tokenIds.compactMap { BigInt($0) } }

            let promises = contractsToTokenIds.map { contract, tokenIds in
                erc1155BalanceFetcher
                    .fetch(contract: contract, tokenIds: Set(tokenIds))
                    .map { (contract: contract, balances: $0 ) }
            }

            return firstly {
                when(fulfilled: promises)
            }.map(on: queue, { contractsAndBalances in
                var contractToTokenIds: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NonFungibleFromTokenUri>]] = .init()

                for each in tokenIdMetaDatas {
                    guard let data = each.jsonAndItsSource.value.data(using: .utf8) else { continue }
                    guard let nonFungible = nonFungible(fromJsonData: data, tokenType: .erc1155) as? NonFungibleFromTokenUri else { continue }
                    var nonFungibles = contractToTokenIds[each.contract] ?? .init()
                    nonFungibles.append(.init(tokenId: each.jsonAndItsSource.tokenId, value: nonFungible, source: each.jsonAndItsSource.source))
                    contractToTokenIds[each.contract] = nonFungibles
                }
                let contractToOpenSeaNonFungiblesWithUpdatedBalances: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NonFungibleFromTokenUri>]] = TokenBalanceFetcher.functional.fillErc1155NonFungiblesWithBalance(contractToNonFungibles: contractToTokenIds, contractsAndBalances: contractsAndBalances)

                return contractToOpenSeaNonFungiblesWithUpdatedBalances
            })
        })
        //TODO: log error remotely
    }

    private func _fetchErc1155NonFungibleJsons(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, enjinTokens: EnjinTokenIdsToSemiFungibles) -> Promise<[TokenIdMetaData]> {
        var allGuarantees: [Guarantee<TokenIdMetaData>] = .init()
        for (contract, tokenIds) in contractsAndTokenIds {
            let guarantees = tokenIds.map { tokenId -> Guarantee<TokenIdMetaData> in
                nonFungibleJsonBalanceFetcher.fetchNonFungibleJson(forTokenId: String(tokenId), tokenType: .erc1155, address: contract, enjinTokens: enjinTokens)
                    .map(on: queue, { jsonAndItsUri -> TokenIdMetaData in
                        return (contract: contract, tokenId: tokenId, jsonAndItsSource: jsonAndItsUri)
                    })
            }
            allGuarantees.append(contentsOf: guarantees)
        }
        return when(fulfilled: allGuarantees)
    }

    private func addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> Promise<Erc1155TokenIds.ContractsAndTokenIds> {
        return firstly {
            fetchUnknownErc1155ContractsDetails(contractsAndTokenIds: contractsAndTokenIds)
        }.map(on: queue, { [tokensService] tokensToAdd in
            tokensService.addCustom(tokens: tokensToAdd, shouldUpdateBalance: false)

            return contractsAndTokenIds
        })
    }

    private func fetchUnknownErc1155ContractsDetails(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> Promise<[ERCToken]> {
        let contractsToAdd: [AlphaWallet.Address] = contractsAndTokenIds.keys.filter { contract in
            tokensService.token(for: contract, server: server) == nil
        }
        guard !contractsToAdd.isEmpty else { return Promise<[ERCToken]>.value(.init()) }
        let (promise, seal) = Promise<[ERCToken]>.pending()
        //Can't use `DispatchGroup` because `ContractDataDetector.fetch()` doesn't call `completion` once and only once
        var contractsProcessed: Set<AlphaWallet.Address> = .init()
        var erc1155TokensToAdd: [ERCToken] = .init()
        func markContractProcessed(_ contract: AlphaWallet.Address) {
            contractsProcessed.insert(contract)
            if contractsProcessed.count == contractsToAdd.count {
                seal.fulfill(erc1155TokensToAdd)
            }
        }
        for each in contractsToAdd {
            ContractDataDetector(address: each, account: account, server: server, assetDefinitionStore: assetDefinitionStore, analytics: analytics).fetch { data in
                switch data {
                case .name, .symbol, .balance, .decimals:
                    break
                case .nonFungibleTokenComplete(let name, let symbol, let balance, let tokenType):
                    let token = ERCToken(
                            contract: each,
                            server: self.server,
                            name: name,
                            symbol: symbol,
                            //Doesn't matter for ERC1155 since it's not used at the token level
                            decimals: 0,
                            type: tokenType,
                            balance: balance
                    )
                    erc1155TokensToAdd.append(token)
                    markContractProcessed(each)
                case .fungibleTokenComplete:
                    markContractProcessed(each)
                case .delegateTokenComplete:
                    markContractProcessed(each)
                case .failed:
                    //TODO we are ignoring `.failed` here because it is called multiple times and we need to wait until `ContractDataDetector.fetch()`'s `completion` is called once and only once
                    break
                }
            }
        }
        return promise
    }
}
