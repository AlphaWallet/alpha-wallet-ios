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
    private let queue = DispatchQueue(label: "org.alphawallet.swift.tokenBalanceFetcher", qos: .utility)
    private let tokensService: TokenProvidable & TokenAddable
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger

    private lazy var nonErc1155BalanceFetcher: TokenProviderType = session.tokenProvider
    private lazy var jsonFromTokenUri: JsonFromTokenUri = {
        return JsonFromTokenUri(blockchainProvider: session.blockchainProvider, tokensService: tokensService, networkService: networkService)
    }()
    private lazy var erc1155TokenIdsFetcher = Erc1155TokenIdsFetcher(analytics: analytics, session: session)
    private lazy var erc1155BalanceFetcher = Erc1155BalanceFetcher(address: session.account.address, blockchainProvider: session.blockchainProvider)
    private lazy var erc1155JsonBalanceFetcher: NonFungibleErc1155JsonBalanceFetcher = {
        let fetcher = NonFungibleErc1155JsonBalanceFetcher(tokensService: tokensService, session: session, erc1155TokenIdsFetcher: erc1155TokenIdsFetcher, jsonFromTokenUri: jsonFromTokenUri, erc1155BalanceFetcher: erc1155BalanceFetcher, importToken: importToken)
        fetcher.delegate = self

        return fetcher
    }()
    private let session: WalletSession
    private let etherToken: Token
    private let importToken: ImportToken
    private let networkService: NetworkService
    private var cancellable = AtomicDictionary<AlphaWallet.Address, AnyCancellable>()

    weak public var delegate: TokenBalanceFetcherDelegate?
    weak public var erc721TokenIdsFetcher: Erc721TokenIdsFetcher?

    public init(session: WalletSession,
                nftProvider: NFTProvider,
                tokensService: TokenProvidable & TokenAddable,
                etherToken: Token,
                assetDefinitionStore: AssetDefinitionStore,
                analytics: AnalyticsLogger,
                importToken: ImportToken,
                networkService: NetworkService) {
        
        self.session = session
        self.networkService = networkService
        self.importToken = importToken
        self.nftProvider = nftProvider
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
            let wallet = session.account.address
            guard cancellable[wallet] == nil else { return }

            cancellable[wallet] = session
                .blockchainProvider
                .balancePublisher(for: wallet)
                .receive(on: queue)
                .sink(receiveCompletion: { [weak self] result in
                    self?.cancellable[wallet] = nil
                    guard case .failure(let error) = result else { return }
                    
                    verboseLog("[Balance Fetcher] failure to fetch balance for wallet: \(wallet)")
                }, receiveValue: { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: etherToken, field: .value(balance.value))])
                })
        }
    }

    private func getBalanceForNonErc721Or1155Tokens(forToken token: Token) {
        switch token.type {
        case .nativeCryptocurrency, .erc721, .erc1155:
            break
        case .erc20:
            nonErc1155BalanceFetcher
                .getErc20Balance(for: token.contractAddress)
                .done(on: queue, { [weak self] value in
                    self?.notifyUpdateBalance([.update(token: token, field: .value(value))])
                }).cauterize()
        case .erc875:
            nonErc1155BalanceFetcher
                .getErc875Balance(for: token.contractAddress)
                .done(on: queue, { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: token, field: .nonFungibleBalance(.erc875(balance)))])
                }).cauterize()
        case .erc721ForTickets:
            nonErc1155BalanceFetcher
                .getErc721ForTicketsBalance(for: token.contractAddress)
                .done(on: queue, { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: token, field: .nonFungibleBalance(.erc721ForTickets(balance)))])
                }).cauterize()
        }
    }

    private func refreshBalanceForErc721Or1155Tokens(tokens: [Token]) {
        assert(!tokens.contains { !$0.isERC721Or1155AndNotForTickets })

        firstly {
            nftProvider.nonFungible(wallet: session.account, server: session.server)
        }.done(on: queue, { [weak self] response in
            guard let strongSelf = self else { return }

            let erc721Or1155ContractsFoundInOpenSea = Array(response.openSea.keys).map { $0 }
            let erc721Or1155ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721Or1155ContractsFoundInOpenSea

            strongSelf.updateNonOpenSeaNonFungiblesBalance(contracts: erc721Or1155ContractsNotFoundInOpenSea, enjinTokens: response.enjin)
            let contractToOpenSeaNonFungibles = response.openSea.mapValues { openSeaJsons in
                return openSeaJsons.map { each -> NonFungibleBalanceAndItsSource<OpenSeaNonFungible> in
                    return .init(tokenId: each.tokenId, value: each, source: .nativeProvider(.openSea))
                }
            }
            strongSelf.updateOpenSeaErc721Tokens(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, enjinTokens: response.enjin)
            strongSelf.updateOpenSeaErc1155Tokens(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, enjinTokens: response.enjin)
        }).cauterize()
    }

    private func updateNonOpenSeaNonFungiblesBalance(contracts: [AlphaWallet.Address], enjinTokens: EnjinTokenIdsToSemiFungibles) {
        let erc721Contracts = erc1155TokenIdsFetcher.filterAwayErc1155Tokens(contracts: contracts)
        erc721Contracts.forEach { updateNonOpenSeaErc721Balance(contract: $0, enjinTokens: enjinTokens) }

        erc1155JsonBalanceFetcher.fetchErc1155NonFungibleJsons(enjinTokens: enjinTokens)
            .done(on: queue, { [weak self] contractToNonFungibles in
                guard let strongSelf = self else { return }
                let ops = strongSelf.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToNonFungibles)
                strongSelf.notifyUpdateBalance(ops)
            }).cauterize()
    }

    private func updateNonOpenSeaErc721Balance(contract: AlphaWallet.Address, enjinTokens: EnjinTokenIdsToSemiFungibles) {
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher else { return }
        firstly {
            erc721TokenIdsFetcher.tokenIdsForErc721Token(contract: contract, forServer: session.server, inAccount: session.account.address)
        }.then(on: queue, { [jsonFromTokenUri] tokenIds -> Promise<[NonFungibleBalanceAndItsSource<JsonString>]> in
            let guarantees: [Promise<NonFungibleBalanceAndItsSource>] = tokenIds
                .map { eachTokenId -> Promise<NonFungibleBalanceAndItsSource<JsonString>> in
                    let enjinToken = enjinTokens[TokenIdConverter.toTokenIdSubstituted(string: eachTokenId)]
                    return jsonFromTokenUri.fetchJsonFromTokenUri(forTokenId: eachTokenId, tokenType: .erc721, address: contract, enjinToken: enjinToken)
                }
            return when(fulfilled: guarantees)
        }).done(on: queue, { [weak self, tokensService] jsons in
            guard let strongSelf = self else { return }

            guard let token = tokensService.token(for: contract, server: strongSelf.session.server) else { return }

            let listOfAssets = jsons.map { NonFungibleBalance.NftAssetRawValue(json: $0.value, source: $0.source) }
            strongSelf.notifyUpdateBalance([
                .update(token: token, field: .nonFungibleBalance(.assets(listOfAssets)))
            ])
        }).cauterize()
    }

    private func buildUpdateNonFungiblesBalanceActions<T: NonFungibleFromJson>(contractToNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<T>]]) -> [AddOrUpdateTokenAction] {
        var actions: [AddOrUpdateTokenAction] = []
        for (contract, nonFungibles) in contractToNonFungibles {

            var listOfAssets = [NonFungibleBalance.NftAssetRawValue]()
            var anyNonFungible: T? = nonFungibles.compactMap { $0.value }.first
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
                    .update(token: token, field: .type(tokenType)),
                    .update(token: token, field: .nonFungibleBalance(.assets(listOfAssets))),
                ]
                if let anyNonFungible = anyNonFungible {
                    actions += [.update(token: token, field: .name(anyNonFungible.contractName))]
                }
            } else {
                let token = ErcToken(contract: contract, server: session.server, name: nonFungibles[0].value.contractName, symbol: nonFungibles[0].value.symbol, decimals: 0, type: tokenType, value: .zero, balance: .assets(listOfAssets))

                actions += [.add(ercToken: token, shouldUpdateBalance: tokenType.shouldUpdateBalanceWhenDetected)]
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
            let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractToOpenSeaNonFungibles.mapValues { $0.compactMap { BigInt($0.tokenId) } }
            //OpenSea API output doesn't include the balance ("value") for each tokenId, it seems. So we have to fetch them:
            let promises = contractsToTokenIds.map { contract, tokenIds in
                erc1155BalanceFetcher
                    .getErc1155Balance(contract: contract, tokenIds: Set(tokenIds))
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

extension TokenBalanceFetcher: NonFungibleErc1155JsonBalanceFetcherDelegate {
    func addTokens(tokensToAdd: [ErcToken]) -> PromiseKit.Promise<Void> {
        firstly {
            .value(tokensToAdd)
        }.map(on: queue, { [tokensService] tokensToAdd in
            let actions = tokensToAdd.map { AddOrUpdateTokenAction.add(ercToken: $0, shouldUpdateBalance: $0.type.shouldUpdateBalanceWhenDetected) }
            tokensService.addOrUpdate(with: actions)
            return ()
        })
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
