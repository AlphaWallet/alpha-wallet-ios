//
//  TokenBalanceFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletLogger
import AlphaWalletOpenSea
import BigInt
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
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger

    private lazy var nonErc1155BalanceFetcher: TokenProviderType = session.tokenProvider
    private lazy var jsonFromTokenUri: JsonFromTokenUri = {
        return JsonFromTokenUri(
            blockchainProvider: session.blockchainProvider,
            tokensDataStore: tokensDataStore,
            transporter: transporter)
    }()

    private lazy var erc1155TokenIdsFetcher = Erc1155TokenIdsFetcher(analytics: analytics, blockNumberProvider: session.blockNumberProvider, blockchainProvider: session.blockchainProvider, wallet: session.account, server: session.server, config: session.config)
    private let identifier = UUID().uuidString

    private lazy var erc1155BalanceFetcher = Erc1155BalanceFetcher(address: session.account.address, blockchainProvider: session.blockchainProvider)

    private lazy var erc1155JsonBalanceFetcher: NonFungibleErc1155JsonBalanceFetcher = {
        let fetcher = NonFungibleErc1155JsonBalanceFetcher(
            tokensDataStore: tokensDataStore,
            server: session.server,
            erc1155TokenIdsFetcher: erc1155TokenIdsFetcher,
            jsonFromTokenUri: jsonFromTokenUri,
            erc1155BalanceFetcher: erc1155BalanceFetcher,
            importToken: session.importToken)

        return fetcher
    }()
    private let session: WalletSession
    private let etherToken: Token
    private let transporter: ApiTransporter
    private var cancellable = AtomicDictionary<String, AnyCancellable>()

    weak public var delegate: TokenBalanceFetcherDelegate?
    weak public var erc721TokenIdsFetcher: Erc721TokenIdsFetcher?

    public init(session: WalletSession,
                tokensDataStore: TokensDataStore,
                etherToken: Token,
                assetDefinitionStore: AssetDefinitionStore,
                analytics: AnalyticsLogger,
                transporter: ApiTransporter) {

        self.session = session
        self.transporter = transporter
        self.nftProvider = session.nftProvider
        self.etherToken = etherToken
        self.tokensDataStore = tokensDataStore
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

    deinit {
        cancellable.values.forEach { $0.value.cancel() }
        cancellable.removeAll()
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
        let wallet = session.account.address

        for etherToken in tokens {
            let randomUuid = "eth-BalanceUpdate-" + wallet.eip55String
            guard cancellable[randomUuid] == nil else { return }

            cancellable[randomUuid] = session.blockchainProvider
                .balance(for: wallet)
                .sink(receiveCompletion: { [weak self] result in
                    self?.cancellable[randomUuid] = nil
                    guard case .failure(let error) = result else { return }

                    verboseLog("[Balance Fetcher] failure to fetch balance for wallet: \(wallet)")
                }, receiveValue: { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: etherToken, field: .value(balance.value))])
                })
        }
    }

    private func getBalanceForNonErc721Or1155Tokens(forToken token: Token) {
        let randomUuid = "\(token.type.rawValue)-BalanceUpdate-" + token.contractAddress.eip55String
        switch token.type {
        case .nativeCryptocurrency, .erc721, .erc1155:
            break
        case .erc20:
            guard cancellable[randomUuid] == nil else { return }

            cancellable[randomUuid] = nonErc1155BalanceFetcher
                .getErc20Balance(for: token.contractAddress)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.cancellable[randomUuid] = .none
                }, receiveValue: { [weak self] value in
                    self?.notifyUpdateBalance([.update(token: token, field: .value(value))])
                })
        case .erc875:
            guard cancellable[randomUuid] == nil else { return }

            cancellable[randomUuid] = nonErc1155BalanceFetcher
                .getErc875TokenBalance(for: session.account.address, contract: token.contractAddress)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.cancellable[randomUuid] = .none
                }, receiveValue: { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: token, field: .nonFungibleBalance(.erc875(balance)))])
                })
        case .erc721ForTickets:
            guard cancellable[randomUuid] == nil else { return }

            cancellable[randomUuid] = nonErc1155BalanceFetcher
                .getErc721ForTicketsBalance(for: token.contractAddress)
                .sink(receiveCompletion: { [weak self] _ in
                    self?.cancellable[randomUuid] = .none
                }, receiveValue: { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: token, field: .nonFungibleBalance(.erc721ForTickets(balance)))])
                })
        }
    }

    private func refreshBalanceForErc721Or1155Tokens(tokens: [Token]) {
        assert(!tokens.contains { !$0.isERC721Or1155AndNotForTickets })

        let randomUuid = "fetchNonFungibleBalances"
        guard cancellable[randomUuid] == nil else { return }

        cancellable[randomUuid] = nftProvider.nonFungible()
            .sink(receiveCompletion: { [weak self] _ in
                self?.cancellable[randomUuid] = nil
            }, receiveValue: { [weak self] response in
                guard let strongSelf = self else { return }

                let erc721Or1155ContractsFoundInOpenSea = Array(response.openSea.keys).map { $0 }
                let erc721Or1155ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721Or1155ContractsFoundInOpenSea

                strongSelf.updateNonOpenSeaNonFungiblesBalance(contracts: erc721Or1155ContractsNotFoundInOpenSea)
                let contractToOpenSeaNonFungibles = response.openSea.mapValues { openSeaJsons in
                    return openSeaJsons.map { each -> NonFungibleBalanceAndItsSource<NftAsset> in
                        return .init(tokenId: each.tokenId, value: each, source: .nativeProvider(.openSea))
                    }
                }

                strongSelf.updateOpenSeaErc721Tokens(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles)
                strongSelf.updateOpenSeaErc1155Tokens(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles)
            })
    }

    private func updateNonOpenSeaNonFungiblesBalance(contracts: [AlphaWallet.Address]) {
        let erc721Contracts = erc1155TokenIdsFetcher.filterAwayErc1155Tokens(contracts: contracts)
        erc721Contracts.forEach { updateNonOpenSeaErc721Balance(contract: $0) }

        let randomUuid = "erc721BalanceUpdate-" + UUID().uuidString
        cancellable[randomUuid] = erc1155JsonBalanceFetcher.fetchErc1155NonFungibleJsons()
            .sink(receiveCompletion: { [weak self] _ in
                self?.cancellable[randomUuid] = nil
            }, receiveValue: { [weak self] contractToNonFungibles in
                guard let strongSelf = self else { return }
                Task { @MainActor in
                    let ops = await strongSelf.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToNonFungibles)
                    strongSelf.notifyUpdateBalance(ops)
                }
            })
    }

    private func updateNonOpenSeaErc721Balance(contract: AlphaWallet.Address) {
        let randomUuid = "updateNonOpenSeaErc721Balance-" + contract.eip55String
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher, cancellable[randomUuid] == nil else { return }

        cancellable[randomUuid] = erc721TokenIdsFetcher
            .tokenIdsForErc721Token(contract: contract, forServer: session.server, inAccount: session.account.address)
            .flatMap { [jsonFromTokenUri] tokenIds -> AnyPublisher<[NonFungibleBalanceAndItsSource<JsonString>], Never> in
                let guarantees = tokenIds.map { jsonFromTokenUri.fetchJsonFromTokenUri(for: $0, tokenType: .erc721, address: contract).mapToResult() }

                return Publishers.MergeMany(guarantees).collect()
                    .map { $0.compactMap { try? $0.get() } }
                    .eraseToAnyPublisher()
            }.sink(receiveCompletion: { [weak self] _ in
                self?.cancellable[randomUuid] = nil
            }, receiveValue: { [weak self, tokensDataStore] jsons in
                guard let strongSelf = self else { return }

                Task { @MainActor in
                    guard let token = await tokensDataStore.token(for: contract, server: strongSelf.session.server) else { return }
                    let listOfAssets = jsons.map { NonFungibleBalance.NftAssetRawValue(json: $0.value, source: $0.source) }
                    strongSelf.notifyUpdateBalance([
                        .update(token: token, field: .nonFungibleBalance(.assets(listOfAssets)))
                    ])
                }
            })
    }

    private func buildUpdateNonFungiblesBalanceActions<T: NonFungibleFromJson>(contractToNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<T>]]) async -> [AddOrUpdateTokenAction] {
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
            if let token = await tokensDataStore.token(for: contract, server: session.server) {
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

    private func updateOpenSeaErc721Tokens(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NftAsset>]]) {
        //All non-ERC1155 to be defensive
        let erc721ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.value.tokenType != .erc1155 }
        Task { @MainActor in
            let ops = await buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: erc721ContractToOpenSeaNonFungibles)
            notifyUpdateBalance(ops)
        }
    }

    private func updateOpenSeaErc1155Tokens(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NftAsset>]]) {
        let erc1155ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.value.tokenType == .erc1155 }

        func _buildErc1155Updater(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [NonFungibleBalanceAndItsSource<NftAsset>]]) async throws -> [AddOrUpdateTokenAction] {
            let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractToOpenSeaNonFungibles.mapValues { $0.compactMap { BigInt($0.tokenId) } }
            //OpenSea API output doesn't include the balance ("value") for each tokenId, it seems. So we have to fetch them:

            let contractsAndBalances: [(contract: AlphaWallet.Address, balances: [BigInt: BigUInt])] = await contractsToTokenIds.asyncCompactMap { contract, tokenIds -> (contract: AlphaWallet.Address, balances: [BigInt: BigUInt])? in
                if let balance: [BigInt: BigUInt] = try? await erc1155BalanceFetcher.getErc1155Balance(contract: contract, tokenIds: Set(tokenIds)) {
                    return (contract: contract, balances: balance)
                } else {
                    return nil
                }
            }.compactMap { $0 }

            let contractToNonFungibles = Self.fillErc1155NonFungiblesWithBalance(contractToNonFungibles: contractToOpenSeaNonFungibles, contractsAndBalances: contractsAndBalances)
            return await self.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToNonFungibles)
        }

        Task { @MainActor in
            let ops = try await _buildErc1155Updater(contractToOpenSeaNonFungibles: erc1155ContractToOpenSeaNonFungibles)
            notifyUpdateBalance(ops)
        }
    }

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
