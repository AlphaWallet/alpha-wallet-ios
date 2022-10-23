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

protocol NonFungibleErc1155JsonBalanceFetcherDelegate: AnyObject {
    func addTokens(tokensToAdd: [ERCToken]) -> Promise<Void>
}

//TODO: think about the name, remove queue later, replace with any publisher
class NonFungibleErc1155JsonBalanceFetcher {
    typealias TokenIdMetaData = (contract: AlphaWallet.Address, tokenId: BigUInt, jsonAndItsSource: NonFungibleBalanceAndItsSource<JsonString>)

    private let jsonFromTokenUri: JsonFromTokenUri
    private let erc1155TokenIdsFetcher: Erc1155TokenIdsFetcher
    private let erc1155BalanceFetcher: Erc1155BalanceFetcher
    private let queue = DispatchQueue(label: "org.alphawallet.swift.nonFungibleErc1155JsonBalanceFetcher")

    private let session: WalletSession
    private let tokensService: TokenProvidable
    private let importToken: ImportToken
    weak var delegate: NonFungibleErc1155JsonBalanceFetcherDelegate?

    init(tokensService: TokenProvidable, session: WalletSession, erc1155TokenIdsFetcher: Erc1155TokenIdsFetcher, jsonFromTokenUri: JsonFromTokenUri, erc1155BalanceFetcher: Erc1155BalanceFetcher, importToken: ImportToken) {
        self.session = session
        self.erc1155TokenIdsFetcher = erc1155TokenIdsFetcher
        self.tokensService = tokensService
        self.jsonFromTokenUri = jsonFromTokenUri
        self.erc1155BalanceFetcher = erc1155BalanceFetcher
        self.importToken = importToken
    }

    func fetchErc1155NonFungibleJsons(enjinTokens: EnjinTokenIdsToSemiFungibles) -> Promise<[AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NonFungibleFromTokenUri>]]> {
        return firstly {
            erc1155TokenIdsFetcher.detectContractsAndTokenIds()
        }.then(on: queue, { contractsAndTokenIds -> Promise<Erc1155TokenIds.ContractsAndTokenIds> in
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
        var allGuarantees: [Promise<TokenIdMetaData>] = .init()
        for (contract, tokenIds) in contractsAndTokenIds {
            let guarantees = tokenIds.map { tokenId -> Promise<TokenIdMetaData> in
                let enjinToken = enjinTokens[TokenIdConverter.toTokenIdSubstituted(string: String(tokenId))]
                return jsonFromTokenUri.fetchJsonFromTokenUri(forTokenId: String(tokenId), tokenType: .erc1155, address: contract, enjinToken: enjinToken)
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
        }.then(on: queue, { [queue] tokensToAdd -> Promise<Erc1155TokenIds.ContractsAndTokenIds> in
            guard let delegate = self.delegate else { return .init(error: PMKError.cancelled) }
            return delegate.addTokens(tokensToAdd: tokensToAdd)
                .map(on: queue, { _ in contractsAndTokenIds })
        })
    }

    private func fetchUnknownErc1155ContractsDetails(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> Promise<[ERCToken]> {
        let contractsToAdd: [AlphaWallet.Address] = contractsAndTokenIds.keys.filter { tokensService.token(for: $0, server: session.server) == nil }
        let promises = contractsToAdd.map { importToken.fetchTokenOrContract(for: $0, server: session.server) }

        return when(resolved: promises).map(on: queue, { result -> [ERCToken] in
            result.compactMap { each -> ERCToken? in
                switch each {
                case .fulfilled(let tokenOrContract):
                    switch tokenOrContract {
                    case .nonFungibleToken(let token): return token
                    case .token, .delegateContracts, .deletedContracts, .fungibleTokenComplete, .none: return nil
                    }
                case .rejected: return nil
                }
            }
        })
    }
}
