//
//  PrivateBalanceFetcher.swift
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
import Result
import SwiftyJSON

protocol PrivateBalanceFetcherDelegate: AnyObject {
    func didUpdateBalance(value operations: [AddOrUpdateTokenAction], in fetcher: PrivateBalanceFetcher)
}

protocol PrivateBalanceFetcherType: AnyObject {
    var server: RPCServer { get }
    var etherToken: Token { get }
    var delegate: PrivateBalanceFetcherDelegate? { get set }
    var erc721TokenIdsFetcher: Erc721TokenIdsFetcher? { get set }

    func refreshBalance(for tokens: [Token])
}

enum TokensDataStoreError: Error {
    case general(error: Error)
}

// swiftlint:disable type_body_length
class PrivateBalanceFetcher: PrivateBalanceFetcherType {
    typealias TokenIdMetaData = (contract: AlphaWallet.Address, tokenId: BigUInt, json: String)

    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private var sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()

    private let account: Wallet
    private let nftProvider: NFTProvider
    private let queue: DispatchQueue
    private let config: Config
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore

    private lazy var nonErc1155BalanceFetcher = TokenProvider(account: account, server: server, queue: queue)
    private lazy var nonFungibleContract = NonFungibleContract(server: server, queue: queue)

    private lazy var erc1155TokenIdsFetcher = Erc1155TokenIdsFetcher(address: account.address, server: server, config: config, queue: queue)
    private lazy var erc1155BalanceFetcher = Erc1155BalanceFetcher(address: account.address, server: server)

    let server: RPCServer
    let etherToken: Token
    weak var delegate: PrivateBalanceFetcherDelegate?
    weak var erc721TokenIdsFetcher: Erc721TokenIdsFetcher?

    init(account: Wallet, nftProvider: NFTProvider, tokensDataStore: TokensDataStore, etherToken: Token, server: RPCServer, config: Config, assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue) {
        self.nftProvider = nftProvider
        self.account = account
        self.server = server
        self.config = config
        self.queue = queue
        self.etherToken = etherToken
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
    }

    func refreshBalance(for tokens: [Token]) {
        guard !isRunningTests() else { return }
        
        let etherTokens = tokens.filter { $0 == etherToken }
        let nonEtherTokens = tokens.filter { $0 != etherToken }

        let notErc721Or1155Tokens = nonEtherTokens.filter { !$0.isERC721Or1155AndNotForTickets }
        let erc721Or1155Tokens = nonEtherTokens.filter { $0.isERC721Or1155AndNotForTickets }

        refreshEtherTokens(tokens: etherTokens)
        refreshBalanceForNonErc721Or1155Tokens(tokens: notErc721Or1155Tokens)
        refreshBalanceForErc721Or1155Tokens(tokens: erc721Or1155Tokens)
    }

    private func notifyUpdateBalance(_ operations: [AddOrUpdateTokenAction]) {
        delegate?.didUpdateBalance(value: operations, in: self)
    }

    private func refreshBalanceForNonErc721Or1155Tokens(tokens: [Token]) {
        assert(!tokens.contains { $0.isERC721Or1155AndNotForTickets })
        tokens.forEach { getBalanceForNonErc721Or1155Tokens(forToken: $0) }
    }

    enum RefreshBalancePolicy {
        case eth
        case all
        case token(token: Token)
    } 

    /// NOTE: here actually alway only one token, made it as array of being able to skip updating ether token
    private func refreshEtherTokens(tokens: [Token]) {
        for etherToken in tokens {
            nonErc1155BalanceFetcher
                .getEthBalance(for: account.address)
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
                    self?.notifyUpdateBalance([.update(token: token, action: .nonFungibleBalance(balance))])
                }).cauterize()
        case .erc721ForTickets:
            nonErc1155BalanceFetcher
                .getERC721ForTicketsBalance(for: token.contractAddress)
                .done(on: queue, { [weak self] balance in
                    self?.notifyUpdateBalance([.update(token: token, action: .nonFungibleBalance(balance))])
                }).cauterize()
        }
    }

    private func refreshBalanceForErc721Or1155Tokens(tokens: [Token]) {
        assert(!tokens.contains { !$0.isERC721Or1155AndNotForTickets })

        firstly {
            nftProvider.nonFungible(wallet: account, server: server)
        }.done(on: queue, { [weak self] response in
            guard let strongSelf = self else { return }

            let contractToOpenSeaNonFungibles = response.openSea
            let enjinTokens = response.enjin

            let erc721Or1155ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721Or1155ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721Or1155ContractsFoundInOpenSea

            strongSelf.updateNonOpenSeaNonFungiblesBalance(contracts: erc721Or1155ContractsNotFoundInOpenSea, enjinTokens: enjinTokens)
            strongSelf.updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, enjinTokens: enjinTokens)
        }).cauterize()
    }

    private func updateNonOpenSeaNonFungiblesBalance(contracts: [AlphaWallet.Address], enjinTokens: EnjinSemiFungiblesToTokenId) {
        let erc721Contracts = filterAwayErc1155Tokens(contracts: contracts)
        erc721Contracts.forEach { updateNonOpenSeaErc721Balance(contract: $0, enjinTokens: enjinTokens) }

        updateNonOpenSeaErc1155Balance(enjinTokens: enjinTokens)
    }

    private func filterAwayErc1155Tokens(contracts: [AlphaWallet.Address]) -> [AlphaWallet.Address] {
        if let erc1155Contracts = erc1155TokenIdsFetcher.knownErc1155Contracts() {
            return contracts.filter { !erc1155Contracts.contains($0) }
        } else {
            return contracts
        }
    }

    private func updateNonOpenSeaErc721Balance(contract: AlphaWallet.Address, enjinTokens: EnjinSemiFungiblesToTokenId) {
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher else { return }
        firstly {
            erc721TokenIdsFetcher.tokenIdsForErc721Token(contract: contract, forServer: server, inAccount: account.address)
        }.then(on: queue, { tokenIds -> Promise<[String]> in
            let guarantees: [Guarantee<String>] = tokenIds
                .map { self.fetchNonFungibleJson(forTokenId: $0, tokenType: .erc721, address: contract, enjinTokens: enjinTokens) }
            return when(fulfilled: guarantees)
        }).done(on: queue, { [weak self, weak tokensDataStore] jsons in
            guard let strongSelf = self else { return }

            guard let token = tokensDataStore?.token(forContract: contract, server: strongSelf.server) else { return }
            strongSelf.notifyUpdateBalance([
                .update(token: token, action: .nonFungibleBalance(jsons))
            ])
        }).cauterize()
    }

    private func updateNonOpenSeaErc1155Balance(enjinTokens: EnjinSemiFungiblesToTokenId) {
        guard Features.default.isAvailable(.isErc1155Enabled) else { return }
        //Local copies so we don't access the wrong ones during async operation

        firstly {
            erc1155TokenIdsFetcher.detectContractsAndTokenIds()
        }.then(on: queue, { contractsAndTokenIds in
            self.addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: contractsAndTokenIds.tokens)
        }).then(on: queue, { (contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> Promise<(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokenIdMetaDatas: [TokenIdMetaData])> in
                self.fetchErc1155NonFungibleJsons(contractsAndTokenIds: contractsAndTokenIds, enjinTokens: enjinTokens)
                    .map { (contractsAndTokenIds: contractsAndTokenIds, tokenIdMetaDatas: $0) }
        }).then(on: queue, { (contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokenIdMetaDatas: [TokenIdMetaData]) -> Promise<[AddOrUpdateTokenAction]> in
            let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractsAndTokenIds
                .mapValues { tokenIds -> [BigInt] in
                    tokenIds.compactMap { BigInt($0) }
                }
            let promises = contractsToTokenIds.map { contract, tokenIds in
                self.erc1155BalanceFetcher
                    .fetch(contract: contract, tokenIds: Set(tokenIds))
                    .map { (contract: contract, balances: $0 ) }
            }
            return firstly {
                when(fulfilled: promises)
            }.map(on: self.queue, { (contractsAndBalances: [(contract: AlphaWallet.Address, balances: [BigInt: BigUInt])]) in
                var contractToTokenIds: [AlphaWallet.Address: [NonFungibleFromTokenUri]] = .init()
                for each in tokenIdMetaDatas {
                    guard let data = each.json.data(using: .utf8) else { continue }
                    guard let nonFungible = nonFungible(fromJsonData: data, tokenType: .erc1155) as? NonFungibleFromTokenUri else { continue }
                    var nonFungibles = contractToTokenIds[each.contract] ?? .init()
                    nonFungibles.append(nonFungible)
                    contractToTokenIds[each.contract] = nonFungibles
                }
                let contractToOpenSeaNonFungiblesWithUpdatedBalances: [AlphaWallet.Address: [NonFungibleFromTokenUri]] = functional.fillErc1155NonFungiblesWithBalance(contractToNonFungibles: contractToTokenIds, contractsAndBalances: contractsAndBalances)
                return self.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToOpenSeaNonFungiblesWithUpdatedBalances as [AlphaWallet.Address: [NonFungibleFromTokenUri]])
            })
        }).done(on: queue, { [weak self] ops in
            self?.notifyUpdateBalance(ops)
        }).cauterize()
        //TODO log error remotely
    }

    func buildUpdateNonFungiblesBalanceActions<T: NonFungibleFromJson>(contractToNonFungibles: [AlphaWallet.Address: [T]]) -> [AddOrUpdateTokenAction] {
        var actions: [AddOrUpdateTokenAction] = []
        for (contract, nonFungibles) in contractToNonFungibles {
            var listOfJson = [String]()
            var anyNonFungible: T?
            for each in nonFungibles {
                if let encodedJson = try? JSONEncoder().encode(each), let jsonString = String(data: encodedJson, encoding: .utf8) {
                    anyNonFungible = each
                    listOfJson.append(jsonString)
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
            if let token = tokensDataStore.token(forContract: contract, server: server) {
                actions += [
                    .update(token: token, action: .type(tokenType)),
                    .update(token: token, action: .nonFungibleBalance(listOfJson)),
                ]
                if let anyNonFungible = anyNonFungible {
                    actions += [.update(token: token, action: .name(anyNonFungible.contractName))]
                }
            } else {
                let token = ERCToken(
                        contract: contract,
                        server: server,
                        name: nonFungibles[0].contractName,
                        symbol: nonFungibles[0].symbol,
                        decimals: 0,
                        type: tokenType,
                        balance: listOfJson
                )

                actions += [.add(token, shouldUpdateBalance: tokenType.shouldUpdateBalanceWhenDetected)]
            }
        }
        return actions
    }

    private func addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> Promise<Erc1155TokenIds.ContractsAndTokenIds> {
        return firstly {
            fetchUnknownErc1155ContractsDetails(contractsAndTokenIds: contractsAndTokenIds)
        }.map(on: queue, { [weak tokensDataStore] tokensToAdd in
            tokensDataStore?.addCustom(tokens: tokensToAdd, shouldUpdateBalance: false)

            return contractsAndTokenIds
        })
    }

    private func fetchErc1155NonFungibleJsons(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, enjinTokens: EnjinSemiFungiblesToTokenId) -> Promise<[TokenIdMetaData]> {
        var allGuarantees: [Guarantee<TokenIdMetaData>] = .init()
        for (contract, tokenIds) in contractsAndTokenIds {
            let guarantees = tokenIds.map { tokenId -> Guarantee<TokenIdMetaData> in
                fetchNonFungibleJson(forTokenId: String(tokenId), tokenType: .erc1155, address: contract, enjinTokens: enjinTokens)
                    .map(on: queue, { jsonString -> TokenIdMetaData in
                        return (contract: contract, tokenId: tokenId, json: jsonString)
                    })
            }
            allGuarantees.append(contentsOf: guarantees)
        }
        return when(fulfilled: allGuarantees)
    }

    //Misnomer, we call this "nonFungible", but this includes ERC1155 which can contain (semi-)fungibles, but there's no better name
    private func fetchNonFungibleJson(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address, enjinTokens: EnjinSemiFungiblesToTokenId) -> Guarantee<String> {
        firstly {
            nonFungibleContract.getTokenUri(for: tokenId, contract: address)
        }.then(on: queue, {
            self.fetchTokenJson(forTokenId: tokenId, tokenType: tokenType, uri: $0, address: address, enjinTokens: enjinTokens)
        }).recover(on: queue, { _ in
            return self.generateTokenJsonFallback(forTokenId: tokenId, tokenType: tokenType, address: address)
        })
    }

    private func fetchTokenJson(forTokenId tokenId: String, tokenType: TokenType, uri originalUri: URL, address: AlphaWallet.Address, enjinTokens: EnjinSemiFungiblesToTokenId) -> Promise<String> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        //TODO check this doesn't print duplicates, including unnecessary fetches
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")
        let server = server
        return firstly {
            //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
            sessionManagerWithDefaultHttpHeaders.request(uri, method: .get).responseData(queue: queue)
        }.map(on: queue, { [weak tokensDataStore] (data, _) -> String in
            if let json = try? JSON(data: data) {
                if let errorMessage = json["error"].string {
                    verboseLog("Fetched token URI: \(originalUri.absoluteString) error: \(errorMessage)")
                }
                if json["error"] == "Internal Server Error" {
                    throw Error()
                } else {
                    verboseLog("Fetched token URI: \(originalUri.absoluteString)")
                    var jsonDictionary = json
                    if let token = tokensDataStore?.token(forContract: address, server: server) {
                        jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
                        //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                        jsonDictionary["contractName"] = JSON(token.name)
                        jsonDictionary["symbol"] = JSON(token.symbol)
                        jsonDictionary["tokenId"] = JSON(tokenId)
                        jsonDictionary["decimals"] = JSON(jsonDictionary["decimals"].intValue)
                        jsonDictionary["name"] = JSON(jsonDictionary["name"].stringValue)
                        jsonDictionary["imageUrl"] = JSON(jsonDictionary["image"].string ?? jsonDictionary["image_url"].string ?? "")
                        jsonDictionary["thumbnailUrl"] = jsonDictionary["imageUrl"]
                        //POAP tokens (https://blockscout.com/xdai/mainnet/address/0x22C1f6050E56d2876009903609a2cC3fEf83B415/transactions), eg. https://api.poap.xyz/metadata/2503/278569, use `home_url` as the key for what they should use `external_url` for and they use `external_url` to point back to the token URI
                        jsonDictionary["externalLink"] = JSON(jsonDictionary["home_url"].string ?? jsonDictionary["external_url"].string ?? "")
                    }
                    let tokenIdSubstituted = TokenIdConverter.toTokenIdSubstituted(string: tokenId)
                    if let enjinToken = enjinTokens[tokenIdSubstituted] {
                        jsonDictionary.update(enjinToken: enjinToken)
                    }

                    if let jsonString = jsonDictionary.rawString() {
                        return jsonString
                    } else {
                        throw Error()
                    }
                }
            } else {
                verboseLog("Fetched token URI: \(originalUri.absoluteString) failed")
                throw Error()
            }
        }).recover { error -> Promise<String> in
            verboseLog("Fetching token URI: \(originalUri) error: \(error)")
            throw error
        }
    }

    /// For development only
    func writeJsonForTransactions(toUrl url: URL, server: RPCServer) {
        guard let transactionStorage = erc721TokenIdsFetcher as? TransactionDataStore else { return }
        transactionStorage.writeJsonForTransactions(toUrl: url, server: server)
    }

    private func fetchUnknownErc1155ContractsDetails(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> Promise<[ERCToken]> {
        let contractsToAdd: [AlphaWallet.Address] = contractsAndTokenIds.keys.filter { contract in
            tokensDataStore.token(forContract: contract, server: server) == nil
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
            ContractDataDetector(address: each, account: account, server: server, assetDefinitionStore: assetDefinitionStore).fetch { data in
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

    private func generateTokenJsonFallback(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address) -> Guarantee<String> {
        var jsonDictionary = JSON()
        if let token = tokensDataStore.token(forContract: address, server: server) {
            jsonDictionary["tokenId"] = JSON(tokenId)
            jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
            jsonDictionary["contractName"] = JSON(token.name)
            jsonDictionary["decimals"] = JSON(0)
            jsonDictionary["symbol"] = JSON(token.symbol)
            jsonDictionary["name"] = ""
            jsonDictionary["imageUrl"] = ""
            jsonDictionary["thumbnailUrl"] = ""
            jsonDictionary["externalLink"] = ""
        }
        return .value(jsonDictionary.rawString()!)
    }

    private func updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]], enjinTokens: EnjinSemiFungiblesToTokenId) {
        var erc1155ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.tokenType == .erc1155 }
        //All non-ERC1155 to be defensive
        let nonErc1155ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.tokenType != .erc1155 }

        func _buildErc1155Updater(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]]) -> Promise<[AddOrUpdateTokenAction]> {
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
            }.map(on: queue, { (contractsAndBalances: [(contract: AlphaWallet.Address, balances: [BigInt: BigUInt])]) in
                functional.fillErc1155NonFungiblesWithBalance(contractToNonFungibles: contractToOpenSeaNonFungibles, contractsAndBalances: contractsAndBalances)
            }).map(on: queue, { contractToOpenSeaNonFungiblesWithUpdatedBalances in
                self.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToOpenSeaNonFungiblesWithUpdatedBalances)
            })
        }

        func _buildNonErc1155Updater(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]]) -> [AddOrUpdateTokenAction] {
            buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToOpenSeaNonFungibles)
        }

        erc1155ContractToOpenSeaNonFungibles = erc1155ContractToOpenSeaNonFungibles.mapValues { element in
            element.map { nonFungibleToken in
                var nonFungible = nonFungibleToken
                if let enjinToken = enjinTokens[nonFungible.tokenIdSubstituted] {
                    nonFungible.update(enjinToken: enjinToken)
                }
                return nonFungible
            }
        }

        firstly {
            _buildErc1155Updater(contractToOpenSeaNonFungibles: erc1155ContractToOpenSeaNonFungibles)
        }.map(on: queue, {
            $0 + _buildNonErc1155Updater(contractToOpenSeaNonFungibles: nonErc1155ContractToOpenSeaNonFungibles)
        }).done(on: queue, { [weak self] ops in
            self?.notifyUpdateBalance(ops)
        }).cauterize()
    }
}
// swiftlint:enable type_body_length

extension PrivateBalanceFetcher {
    class functional {}
}

fileprivate extension PrivateBalanceFetcher.functional {
    static func fillErc1155NonFungiblesWithBalance<T: NonFungibleFromJson>(contractToNonFungibles: [AlphaWallet.Address: [T]], contractsAndBalances: [(contract: AlphaWallet.Address, balances: [BigInt: BigUInt])]) -> [AlphaWallet.Address: [T]] {
        let contractsAndBalances = Dictionary(uniqueKeysWithValues: contractsAndBalances)
        let contractToNonFungiblesWithUpdatedBalances: [AlphaWallet.Address: [T]] = Dictionary(uniqueKeysWithValues: contractToNonFungibles.map { contract, nonFungibles in
            let nonFungiblesWithUpdatedBalance = nonFungibles.map { each -> T in
                if let tokenId = BigInt(each.tokenId), let balances = contractsAndBalances[contract], let value = balances[tokenId] {
                    var tokenWithBalance = each
                    tokenWithBalance.value = BigInt(value)
                    return tokenWithBalance
                } else {
                    return each
                }
            }
            return (contract, nonFungiblesWithUpdatedBalance)
        })
        return contractToNonFungiblesWithUpdatedBalances
    }
}
