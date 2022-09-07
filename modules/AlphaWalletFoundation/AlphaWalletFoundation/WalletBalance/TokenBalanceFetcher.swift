//
//  TokenBalanceFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletOpenSea
import BigInt
import PromiseKit
import SwiftyJSON

public protocol TokenBalanceFetcherDelegate: AnyObject {
    func didUpdateBalance(value operations: [AddOrUpdateTokenAction], in fetcher: TokenBalanceFetcher)
}

public protocol TokenBalanceFetcherType: AnyObject {
    var delegate: TokenBalanceFetcherDelegate? { get set }
    var erc721TokenIdsFetcher: Erc721TokenIdsFetcher? { get set }

    func refreshBalance(for tokens: [Token])
    func cancel()
}

public class TokenBalanceFetcher: TokenBalanceFetcherType {
    private let nftProvider: NFTProvider
    private let queue: DispatchQueue
    private let tokensService: TokenProvidable & TokenAddable
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger

    private lazy var nonErc1155BalanceFetcher: TokenProviderType = session.tokenProvider
    private lazy var nonFungibleJsonBalanceFetcher = NonFungibleJsonBalanceFetcher(server: session.server, tokensService: tokensService, queue: queue)
    private lazy var erc1155TokenIdsFetcher = Erc1155TokenIdsFetcher(address: session.account.address, server: session.server, config: session.config, queue: queue)
    private lazy var erc1155BalanceFetcher = Erc1155BalanceFetcher(address: session.account.address, server: session.server)
    private lazy var erc1155JsonBalanceFetcher: NonFungibleErc1155JsonBalanceFetcher = {
        return NonFungibleErc1155JsonBalanceFetcher(assetDefinitionStore: assetDefinitionStore, analytics: analytics, tokensService: tokensService, account: session.account, server: session.server, erc1155TokenIdsFetcher: erc1155TokenIdsFetcher, nonFungibleJsonBalanceFetcher: nonFungibleJsonBalanceFetcher, erc1155BalanceFetcher: erc1155BalanceFetcher, queue: queue)
    }()
    private let session: WalletSession
    private let etherToken: Token

    weak public var delegate: TokenBalanceFetcherDelegate?
    weak public var erc721TokenIdsFetcher: Erc721TokenIdsFetcher? 

    public init(session: WalletSession, nftProvider: NFTProvider, tokensService: TokenProvidable & TokenAddable, etherToken: Token, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, queue: DispatchQueue) {
        self.session = session
        self.nftProvider = nftProvider
        self.queue = queue
        self.etherToken = etherToken
        self.tokensService = tokensService
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics

        assert(etherToken.server == session.server)
    }

    public func refreshBalance(for tokens: [Token]) {
        guard !isRunningTests() else { return }

        let etherTokens = tokens.filter { $0 == etherToken }
        let nonEtherTokens = tokens.filter { $0 != etherToken }

        let notErc721Or1155Tokens = nonEtherTokens.filter { !$0.isERC721Or1155AndNotForTickets }
        let erc721Or1155Tokens = nonEtherTokens.filter { $0.isERC721Or1155AndNotForTickets }

        refreshEtherTokens(tokens: etherTokens)
        refreshBalanceForNonErc721Or1155Tokens(tokens: notErc721Or1155Tokens)
        refreshBalanceForErc721Or1155Tokens(tokens: erc721Or1155Tokens)
    }

    public func cancel() {
        //implement request cancel here
    }

    private func notifyUpdateBalance(_ operations: [AddOrUpdateTokenAction]) {
        delegate?.didUpdateBalance(value: operations, in: self)
    }

    private func refreshBalanceForNonErc721Or1155Tokens(tokens: [Token]) {
        assert(!tokens.contains { $0.isERC721Or1155AndNotForTickets })
        tokens.forEach { getBalanceForNonErc721Or1155Tokens(forToken: $0) }
    }

    public enum RefreshBalancePolicy {
        case eth
        case all
        case tokens(tokens: [Token])
        case token(token: Token)
    }

    /// NOTE: here actually alway only one token, made it as array of being able to skip updating ether token
    private func refreshEtherTokens(tokens: [Token]) {
        for etherToken in tokens {
            nonErc1155BalanceFetcher
                .getEthBalance(for: session.account.address)
                .done(on: queue, { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: etherToken, action: .value(balance.value))])
                }).cauterize()
        }
    }

    private func getBalanceForNonErc721Or1155Tokens(forToken token: Token) {
        switch token.type {
        case .nativeCryptocurrency, .erc721, .erc1155:
            break
        case .erc20:
            nonErc1155BalanceFetcher
                .getERC20Balance(for: token.contractAddress)
                .done(on: queue, { [weak self] value in
                    self?.notifyUpdateBalance([.update(token: token, action: .value(value))])
                }).cauterize()
        case .erc875:
            nonErc1155BalanceFetcher
                .getERC875Balance(for: token.contractAddress)
                .done(on: queue, { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: token, action: .nonFungibleBalance(.erc875(balance)))])
                }).cauterize()
        case .erc721ForTickets:
            nonErc1155BalanceFetcher
                .getERC721ForTicketsBalance(for: token.contractAddress)
                .done(on: queue, { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: token, action: .nonFungibleBalance(.erc721ForTickets(balance)))])
                }).cauterize()
        }
    }

    private func refreshBalanceForErc721Or1155Tokens(tokens: [Token]) {
        assert(!tokens.contains { !$0.isERC721Or1155AndNotForTickets })

        firstly {
            nftProvider.nonFungible(wallet: session.account, server: session.server)
        }.done(on: queue, { [weak self] response in
            guard let strongSelf = self else { return }

            let enjinTokens = response.enjin

            let erc721Or1155ContractsFoundInOpenSea = Array(response.openSea.keys).map { $0 }
            let erc721Or1155ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721Or1155ContractsFoundInOpenSea

            strongSelf.updateNonOpenSeaNonFungiblesBalance(contracts: erc721Or1155ContractsNotFoundInOpenSea, enjinTokens: enjinTokens)
            let contractToOpenSeaNonFungibles = response.openSea.mapValues { openSeaJsons in
                return openSeaJsons.map { each -> NonFungibleBalanceAndItsSource<OpenSeaNonFungible> in
                    return .init(tokenId: each.tokenId, value: each, source: .nativeProvider(.openSea))
                }
            }
            strongSelf.updateOpenSeaErc721Tokens(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, enjinTokens: enjinTokens)
            strongSelf.updateOpenSeaErc1155Tokens(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, enjinTokens: enjinTokens)
        }).cauterize()
    }

    private func updateNonOpenSeaNonFungiblesBalance(contracts: [AlphaWallet.Address], enjinTokens: EnjinTokenIdsToSemiFungibles) {
        let erc721Contracts = filterAwayErc1155Tokens(contracts: contracts)
        erc721Contracts.forEach { updateNonOpenSeaErc721Balance(contract: $0, enjinTokens: enjinTokens) }

        erc1155JsonBalanceFetcher.fetchErc1155NonFungibleJsons(enjinTokens: enjinTokens)
            .done(on: queue, { [weak self] contractToNonFungibles in
                guard let strongSelf = self else { return }
                let ops = strongSelf.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToNonFungibles)
                strongSelf.notifyUpdateBalance(ops)
            }).cauterize()
    }

    private func filterAwayErc1155Tokens(contracts: [AlphaWallet.Address]) -> [AlphaWallet.Address] {
        if let erc1155Contracts = erc1155TokenIdsFetcher.knownErc1155Contracts() {
            return contracts.filter { !erc1155Contracts.contains($0) }
        } else {
            return contracts
        }
    }

    private func updateNonOpenSeaErc721Balance(contract: AlphaWallet.Address, enjinTokens: EnjinTokenIdsToSemiFungibles) {
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher else { return }
        firstly {
            erc721TokenIdsFetcher.tokenIdsForErc721Token(contract: contract, forServer: session.server, inAccount: session.account.address)
        }.then(on: queue, { [nonFungibleJsonBalanceFetcher] tokenIds -> Promise<[NonFungibleBalanceAndItsSource<JsonString>]> in
            let guarantees: [Guarantee<NonFungibleBalanceAndItsSource>] = tokenIds
                .map { nonFungibleJsonBalanceFetcher.fetchNonFungibleJson(forTokenId: $0, tokenType: .erc721, address: contract, enjinTokens: enjinTokens) }
            return when(fulfilled: guarantees)
        }).done(on: queue, { [weak self, tokensService] jsons in
            guard let strongSelf = self else { return }

            guard let token = tokensService.token(for: contract, server: strongSelf.session.server) else { return }

            let listOfAssets = jsons.map { NonFungibleBalance.NftAssetRawValue(json: $0.value, source: $0.source) }
            strongSelf.notifyUpdateBalance([
                .update(token: token, action: .nonFungibleBalance(.assets(listOfAssets)))
            ])
        }).cauterize()
    }

    private func buildUpdateNonFungiblesBalanceActions<T: NonFungibleFromJson>(contractToNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<T>]]) -> [AddOrUpdateTokenAction] {
        var actions: [AddOrUpdateTokenAction] = []
        for (contract, nonFungibles) in contractToNonFungibles {

            var listOfAssets = [NonFungibleBalance.NftAssetRawValue]()
            var anyNonFungible: T?
            for each in nonFungibles {
                if let encodedJson = try? JSONEncoder().encode(each.value), let jsonString = String(data: encodedJson, encoding: .utf8) {
                    anyNonFungible = each.value
                    listOfAssets.append(.init(json: jsonString, source: each.source))
                } else {
                    //no op
                }
            }

            let tokenType: TokenType
            if let anyNonFungible = anyNonFungible {
                tokenType = anyNonFungible.tokenType.asTokenType
            } else {
                //Default to ERC721 because this is what we supported (from OpenSea) before adding ERC1155 support
                tokenType = .erc721
            }
            if let token = tokensService.token(for: contract, server: session.server) {
                actions += [
                    .update(token: token, action: .type(tokenType)),
                    .update(token: token, action: .nonFungibleBalance(.assets(listOfAssets))),
                ]
                if let anyNonFungible = anyNonFungible {
                    actions += [.update(token: token, action: .name(anyNonFungible.contractName))]
                }
            } else {
                let token = ERCToken(
                        contract: contract,
                        server: session.server,
                        name: nonFungibles[0].value.contractName,
                        symbol: nonFungibles[0].value.symbol,
                        decimals: 0,
                        type: tokenType,
                        balance: .assets(listOfAssets))

                actions += [.add(token, shouldUpdateBalance: tokenType.shouldUpdateBalanceWhenDetected)]
            }
        }
        return actions
    }

    /// For development only
    func writeJsonForTransactions(toUrl url: URL, server: RPCServer) {
        guard let transactionStorage = erc721TokenIdsFetcher as? TransactionDataStore else { return }
        transactionStorage.writeJsonForTransactions(toUrl: url, server: server)
    }

    private func updateOpenSeaErc721Tokens(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<OpenSeaNonFungible>]], enjinTokens: EnjinTokenIdsToSemiFungibles) {
        //All non-ERC1155 to be defensive
        let erc721ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.value.tokenType != .erc1155 }
        let ops = buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: erc721ContractToOpenSeaNonFungibles)
        notifyUpdateBalance(ops)
    }

    private func updateOpenSeaErc1155Tokens(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<OpenSeaNonFungible>]], enjinTokens: EnjinTokenIdsToSemiFungibles) {
        var erc1155ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.value.tokenType == .erc1155 }

        func _buildErc1155Updater(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<OpenSeaNonFungible>]]) -> Promise<[AddOrUpdateTokenAction]> {
            let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractToOpenSeaNonFungibles.mapValues { openSeaNonFungibles -> [BigInt] in
                openSeaNonFungibles.compactMap { BigInt($0.tokenId) }
            }
            //OpenSea API output doesn't include the balance ("value") for each tokenId, it seems. So we have to fetch them:
            let promises = contractsToTokenIds.map { contract, tokenIds in
                erc1155BalanceFetcher
                    .fetch(contract: contract, tokenIds: Set(tokenIds))
                    .map(on: queue, { (contract: contract, balances: $0) })
                    .recover(on: queue, { _ in return .value((contract: contract, balances: [:])) })
            }
            return firstly {
                when(fulfilled: promises)
            }.map(on: queue, { contractsAndBalances in
                functional.fillErc1155NonFungiblesWithBalance(contractToNonFungibles: contractToOpenSeaNonFungibles, contractsAndBalances: contractsAndBalances)
            }).map(on: queue, { contractToOpenSeaNonFungiblesWithUpdatedBalances in
                self.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToOpenSeaNonFungiblesWithUpdatedBalances)
            })
        }

        erc1155ContractToOpenSeaNonFungibles = erc1155ContractToOpenSeaNonFungibles.mapValues { element in
            element.map { each in
                var nonFungible = each.value
                if let enjinToken = enjinTokens[nonFungible.tokenIdSubstituted] {
                    nonFungible.update(enjinToken: enjinToken)
                }
                return .init(tokenId: each.tokenId, value: nonFungible, source: each.source)
            }
        }

        firstly {
            _buildErc1155Updater(contractToOpenSeaNonFungibles: erc1155ContractToOpenSeaNonFungibles)
        }.done(on: queue, { [weak self] ops in
            self?.notifyUpdateBalance(ops)
        }).cauterize()
    }
}

extension TokenBalanceFetcher {
    class functional {}
}

extension TokenBalanceFetcher.functional {
    static func fillErc1155NonFungiblesWithBalance<T: NonFungibleFromJson>(contractToNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<T>]], contractsAndBalances: [(contract: AlphaWallet.Address, balances: [BigInt: BigUInt])]) -> [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<T>]] {
        let contractsAndBalances = Dictionary(uniqueKeysWithValues: contractsAndBalances)
        let contractToNonFungiblesWithUpdatedBalances: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<T>]] = Dictionary(uniqueKeysWithValues: contractToNonFungibles.map { contract, nonFungibles in
            let nonFungiblesWithUpdatedBalance = nonFungibles.map { each -> NonFungibleBalanceAndItsSource<T> in
                if let tokenId = BigInt(each.tokenId), let balances = contractsAndBalances[contract], let value = balances[tokenId] {
                    var tokenWithBalance = each.value
                    tokenWithBalance.value = BigInt(value)
                    return .init(tokenId: each.tokenId, value: tokenWithBalance, source: each.source)
                } else {
                    return each
                }
            }
            return (contract, nonFungiblesWithUpdatedBalance)
        })
        return contractToNonFungiblesWithUpdatedBalances
    }
}
