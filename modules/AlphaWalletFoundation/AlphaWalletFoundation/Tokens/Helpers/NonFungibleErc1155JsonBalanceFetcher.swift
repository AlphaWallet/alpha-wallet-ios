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
import SwiftyJSON

//TODO: think about the name, remove queue later, replace with any publisher
class NonFungibleErc1155JsonBalanceFetcher {
    typealias TokenIdMetaData = (contract: AlphaWallet.Address, tokenId: BigUInt, jsonAndItsSource: NonFungibleBalanceAndItsSource<JsonString>)

    private let jsonFromTokenUri: JsonFromTokenUri
    private let erc1155TokenIdsFetcher: Erc1155TokenIdsFetcher
    private let erc1155BalanceFetcher: Erc1155BalanceFetcher

    private let session: WalletSession
    private let tokensService: TokenProvidable
    private let importToken: ImportToken

    init(tokensService: TokenProvidable, session: WalletSession, erc1155TokenIdsFetcher: Erc1155TokenIdsFetcher, jsonFromTokenUri: JsonFromTokenUri, erc1155BalanceFetcher: Erc1155BalanceFetcher, importToken: ImportToken) {
        self.session = session
        self.erc1155TokenIdsFetcher = erc1155TokenIdsFetcher
        self.tokensService = tokensService
        self.jsonFromTokenUri = jsonFromTokenUri
        self.erc1155BalanceFetcher = erc1155BalanceFetcher
        self.importToken = importToken
    }

    func fetchErc1155NonFungibleJsons(enjinTokens: EnjinTokenIdsToSemiFungibles) -> AnyPublisher<[AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NonFungibleFromTokenUri>]], SessionTaskError> {
        return erc1155TokenIdsFetcher
            .detectContractsAndTokenIds()
            .mapError { SessionTaskError(error: $0) }
            .flatMap { contractsAndTokenIds -> AnyPublisher<Erc1155TokenIds.ContractsAndTokenIds, SessionTaskError> in
                self.addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: contractsAndTokenIds.tokens)
            }.flatMap { contractsAndTokenIds -> AnyPublisher<(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokenIdMetaDatas: [TokenIdMetaData]), SessionTaskError> in
                self._fetchErc1155NonFungibleJsons(contractsAndTokenIds: contractsAndTokenIds, enjinTokens: enjinTokens)
                    .map { (contractsAndTokenIds: contractsAndTokenIds, tokenIdMetaDatas: $0) }
                    .eraseToAnyPublisher()
            }.flatMap { [erc1155BalanceFetcher] (contractsAndTokenIds, tokenIdMetaDatas) -> AnyPublisher<[AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NonFungibleFromTokenUri>]], SessionTaskError> in
                let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractsAndTokenIds
                    .mapValues { tokenIds -> [BigInt] in tokenIds.compactMap { BigInt($0) } }

                let promises = contractsToTokenIds.map { contract, tokenIds in
                    erc1155BalanceFetcher
                        .getErc1155Balance(contract: contract, tokenIds: Set(tokenIds))
                        .map { (contract: contract, balances: $0 ) }
                }

                return Publishers.MergeMany(promises)
                    .collect()
                    .map { contractsAndBalances in
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
                    }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()

        //TODO: log error remotely
    }

    private func _fetchErc1155NonFungibleJsons(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, enjinTokens: EnjinTokenIdsToSemiFungibles) -> AnyPublisher<[TokenIdMetaData], SessionTaskError> {
        var allGuarantees: [AnyPublisher<TokenIdMetaData, SessionTaskError>] = .init()
        for (contract, tokenIds) in contractsAndTokenIds {
            let guarantees = tokenIds.map { tokenId -> AnyPublisher<TokenIdMetaData, SessionTaskError> in
                let enjinToken = enjinTokens[TokenIdConverter.toTokenIdSubstituted(string: String(tokenId))]
                return jsonFromTokenUri.fetchJsonFromTokenUri(forTokenId: String(tokenId), tokenType: .erc1155, address: contract, enjinToken: enjinToken)
                    .map { jsonAndItsUri -> TokenIdMetaData in
                        return (contract: contract, tokenId: tokenId, jsonAndItsSource: jsonAndItsUri)
                    }.eraseToAnyPublisher()
            }

            allGuarantees.append(contentsOf: guarantees)
        }

        return Publishers.MergeMany(allGuarantees)
            .collect()
            .eraseToAnyPublisher()
    }

    private func addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> AnyPublisher<Erc1155TokenIds.ContractsAndTokenIds, SessionTaskError> {
        importUnknownErc1155Contracts(contractsAndTokenIds: contractsAndTokenIds)
    }

    private func importUnknownErc1155Contracts(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> AnyPublisher<Erc1155TokenIds.ContractsAndTokenIds, SessionTaskError> {
        let promises = contractsAndTokenIds.keys.map { importToken.importTokenPublisher(for: $0, server: session.server, onlyIfThereIsABalance: false).mapToResult() }
        return Publishers.MergeMany(promises)
            .collect()
            .map { [session] results -> Erc1155TokenIds.ContractsAndTokenIds in
                let tokens = results.compactMap { return try? $0.get() }
                return contractsAndTokenIds.filter { value in
                    tokens.contains(where: { $0.contractAddress == value.key && $0.server == session.server })
                }
            }.setFailureType(to: SessionTaskError.self)
            .eraseToAnyPublisher()
    }
}
