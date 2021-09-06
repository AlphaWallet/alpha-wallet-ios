//
//  PrivateBalanceFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.05.2021.
//

import Foundation
import BigInt
import PromiseKit
import Result
import RealmSwift
import SwiftyJSON

protocol PrivateTokensDataStoreDelegate: AnyObject {
    func didUpdate(in tokensDataStore: PrivateBalanceFetcher)
    func didAddToken(in tokensDataStore: PrivateBalanceFetcher)
}

protocol PrivateBalanceFetcherType: AnyObject {
    var delegate: PrivateTokensDataStoreDelegate? { get set }
    var erc721TokenIdsFetcher: Erc721TokenIdsFetcher? { get set }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool)
}

// swiftlint:disable type_body_length
class PrivateBalanceFetcher: PrivateBalanceFetcherType {
    typealias TokenIdMetaData = (contract: AlphaWallet.Address, tokenId: BigUInt, json: String, value: BigInt)

    static let fetchContractDataTimeout = TimeInterval(4)
    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private var sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()
    weak var erc721TokenIdsFetcher: Erc721TokenIdsFetcher?

    private lazy var tokenProvider: TokenProviderType = {
        return TokenProvider(account: account, server: server, queue: queue)
    }()

    private let account: Wallet

    private let openSea: OpenSea
    private let queue: DispatchQueue
    private let server: RPCServer
    private lazy var etherToken = Activity.AssignedToken(tokenObject: TokensDataStore.etherToken(forServer: server))
    private var isRefeshingBalance: Bool = false
    weak var delegate: PrivateTokensDataStoreDelegate?
    private var enabledObjectsObservation: NotificationToken?
    private let tokensDatastore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore

    init(account: Wallet, tokensDatastore: TokensDataStore, server: RPCServer, assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue) {
        self.account = account
        self.server = server
        self.queue = queue
        self.openSea = OpenSea.createInstance(forServer: server)
        self.tokensDatastore = tokensDatastore
        self.assetDefinitionStore = assetDefinitionStore

        //NOTE: fire refresh balance only for initial scope, and while adding new tokens
        enabledObjectsObservation = tokensDatastore.enabledObjectResults.observe(on: queue) { [weak self] change in
            guard let strongSelf = self else { return }

            switch change {
            case .initial(let tokenObjects):
                let tokenObjects = tokenObjects.map { Activity.AssignedToken(tokenObject: $0) }

                strongSelf.refreshBalance(tokenObjects: Array(tokenObjects), updatePolicy: .all, force: true)
            case .update(let updates, _, let insertions, _):
                let values = updates.map { Activity.AssignedToken(tokenObject: $0) }
                let tokenObjects = insertions.map { values[$0] }
                guard !tokenObjects.isEmpty else { return }

                strongSelf.refreshBalance(tokenObjects: tokenObjects, updatePolicy: .all, force: true)

                strongSelf.delegate?.didAddToken(in: strongSelf)
            case .error:
                break
            }
        }
    }

    deinit {
        enabledObjectsObservation.flatMap { $0.invalidate() }
    }

    private func getTokensFromOpenSea() -> OpenSea.PromiseResult {
        //TODO when we no longer create multiple instances of TokensDataStore, we don't have to use singleton for OpenSea class. This was to avoid fetching multiple times from OpenSea concurrently
        return openSea.makeFetchPromise(forOwner: account.address)
    }

    func refreshBalance(updatePolicy: RefreshBalancePolicy, force: Bool = false) {
        Promise<[Activity.AssignedToken]> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let tokenObjects = strongSelf.tokensDatastore.tokenObjects

                seal.fulfill(tokenObjects)
            }
        }.done(on: queue, { tokenObjects in
            self.refreshBalance(tokenObjects: tokenObjects, updatePolicy: .all, force: false)
        }).cauterize()
    }

    private func refreshBalanceForNonErc721Or1155Tokens(tokens: [Activity.AssignedToken]) -> Promise<[PrivateBalanceFetcher.TokenBatchOperation]> {
        assert(!tokens.contains { $0.isERC721Or1155AndNotForTickets })

        let promises = tokens.map { getBalanceForNonErc721Or1155Tokens(forToken: $0) }

        return when(resolved: promises).map { values -> [PrivateBalanceFetcher.TokenBatchOperation] in
            return values.compactMap { $0.optionalValue }.compactMap { $0 }
        }
    }

    enum RefreshBalancePolicy {
        case eth
        case ercTokens
        case all
    }

    private func refreshBalance(tokenObjects: [Activity.AssignedToken], updatePolicy: RefreshBalancePolicy, force: Bool = false) {
        guard !isRefeshingBalance || force else { return }

        isRefeshingBalance = true
        let group: DispatchGroup = .init()
        var promises: [Promise<Bool?>] = []

        switch updatePolicy {
        case .all:
            promises += [refreshEthBalance(etherToken: etherToken)]
            promises += [refreshBalance(tokenObjects: tokenObjects, group: group)]
        case .ercTokens:
            promises += [refreshBalance(tokenObjects: tokenObjects, group: group)]
        case .eth:
            promises += [refreshEthBalance(etherToken: etherToken)]
        }

        group.notify(queue: queue) {
            self.isRefeshingBalance = false
        }

        firstly {
            when(resolved: promises).map(on: queue, { values -> Bool? in
                //NOTE: taking for first element means that values was updated
                return values.compactMap { $0.optionalValue }.compactMap { $0 }.first
            })
        }.done(on: queue, { balanceValueHasChange in
            self.isRefeshingBalance = false

            if let value = balanceValueHasChange, value {
                self.delegate.flatMap { $0.didUpdate(in: self) }
            }
        })
    }

    private func refreshEthBalance(etherToken: Activity.AssignedToken) -> Promise<Bool?> {
        let tokensDatastore = self.tokensDatastore

        return tokenProvider.getEthBalance(for: account.address).then(on: queue, { balance -> Promise<Bool?> in
            tokensDatastore.updateTokenPromise(primaryKey: etherToken.primaryKey, action: .value(balance.value))
        }).recover(on: queue, { _ -> Guarantee<Bool?> in
            return .value(nil)
        })
    }

    private func refreshBalance(tokenObjects: [Activity.AssignedToken], group: DispatchGroup) -> Promise<Bool?> {
        let updateTokens = tokenObjects.filter { $0 != etherToken }

        let notErc721Or1155Tokens = updateTokens.filter { !$0.isERC721Or1155AndNotForTickets }
        let erc721Or1155Tokens = updateTokens.filter { $0.isERC721Or1155AndNotForTickets }

        let promise1 = refreshBalanceForNonErc721Or1155Tokens(tokens: notErc721Or1155Tokens)
        let promise2 = refreshBalanceForErc721Or1155Tokens(tokens: erc721Or1155Tokens)

        return when(resolved: [promise1, promise2]).then(on: queue, { value -> Promise<Bool?> in
            let resolved = value.compactMap { $0.optionalValue }.flatMap { $0 }

            return self.tokensDatastore.batchUpdateTokenPromise(resolved).recover { _ -> Guarantee<Bool?> in
                return .value(nil)
            }
        })
    }

    enum TokenBatchOperation {
        case add(ERCToken, shouldUpdateBalance: Bool)
        case update(tokenObject: Activity.AssignedToken, action: TokensDataStore.TokenUpdateAction)
    }

    private func getBalanceForNonErc721Or1155Tokens(forToken tokenObject: Activity.AssignedToken) -> Promise<TokenBatchOperation?> {
        switch tokenObject.type {
        case .nativeCryptocurrency:
            return .value(nil)
        case .erc20:
            return tokenProvider.getERC20Balance(for: tokenObject.contractAddress).map(on: queue, { value -> TokenBatchOperation in
                return .update(tokenObject: tokenObject, action: .value(value))
            }).recover { _ -> Promise<TokenBatchOperation?> in
                return .value(nil)
            }
        case .erc875:
            return tokenProvider.getERC875Balance(for: tokenObject.contractAddress).map(on: queue, { balance -> TokenBatchOperation in
                return .update(tokenObject: tokenObject, action: .nonFungibleBalance(balance))
            }).recover { _ -> Promise<TokenBatchOperation?> in
                return .value(nil)
            }
        case .erc721, .erc1155:
            return .value(nil)
        case .erc721ForTickets:
            return tokenProvider.getERC721ForTicketsBalance(for: tokenObject.contractAddress).map(on: queue, { balance -> TokenBatchOperation in
                return .update(tokenObject: tokenObject, action: .nonFungibleBalance(balance))
            }).recover { _ -> Promise<TokenBatchOperation?> in
                return .value(nil)
            }
        }
    }

    private func refreshBalanceForErc721Or1155Tokens(tokens: [Activity.AssignedToken]) -> Promise<[PrivateBalanceFetcher.TokenBatchOperation]> {
        assert(!tokens.contains { !$0.isERC721Or1155AndNotForTickets })
        return firstly {
            getTokensFromOpenSea()
        }.then(on: queue, { [weak self] contractToOpenSeaNonFungibles -> Guarantee<[PrivateBalanceFetcher.TokenBatchOperation]> in
            guard let strongSelf = self else { return .value([]) }

            let erc721Or1155ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721Or1155ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721Or1155ContractsFoundInOpenSea
            let p1 = strongSelf.updateNonOpenSeaNonFungiblesBalance2(contracts: erc721Or1155ContractsNotFoundInOpenSea, tokens: tokens)
            let p2 = strongSelf.updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, tokens: tokens)

            return when(resolved: [p1, p2]).map(on: strongSelf.queue, { results -> [PrivateBalanceFetcher.TokenBatchOperation] in
                return results.compactMap { $0.optionalValue }.flatMap { $0 }
            })
        })
    }

    private func updateNonOpenSeaNonFungiblesBalance2(contracts: [AlphaWallet.Address], tokens: [Activity.AssignedToken]) -> Promise<[PrivateBalanceFetcher.TokenBatchOperation]> {
        let promises = contracts.map { updateNonOpenSeaNonFungiblesBalance2(erc721Or1115ContractNotFoundInOpenSea: $0, tokens: tokens) }

        return firstly {
            when(fulfilled: promises)
        }.map(on: queue, { results in
            return results.compactMap { $0 }.flatMap { $0 }
        })
    }

    private func updateNonOpenSeaNonFungiblesBalance2(erc721Or1115ContractNotFoundInOpenSea contract: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Promise<[TokenBatchOperation]> {
        let erc721Promise = updateNonOpenSeaErc721Balance2(contract: contract, tokens: tokens)
        let erc1155Promise: Promise<TokenBatchOperation?> = Promise.value(nil)

        return firstly {
            when(fulfilled: [erc721Promise, erc1155Promise]).map(on: queue, { results -> [TokenBatchOperation] in
                return results.compactMap { $0 }
            })
        }
    }

    private func updateNonOpenSeaErc721Balance2(contract: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Promise<TokenBatchOperation?> {
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher else { return Promise { _ in } }
        return firstly {
            erc721TokenIdsFetcher.tokenIdsForErc721Token(contract: contract, inAccount: account.address)
        }.then(on: queue, { tokenIds -> Promise<[String]> in
            let guarantees: [Guarantee<String>] = tokenIds.map { self.fetchNonFungibleJson(forTokenId: $0, address: contract, tokens: tokens) }
            return when(fulfilled: guarantees)
        }).map(on: queue, { jsons -> TokenBatchOperation? in
            guard let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) else {
                return nil
            }
            return .update(tokenObject: tokenObject, action: .nonFungibleBalance(jsons))
        }).recover { _ -> Guarantee<TokenBatchOperation?> in
            return .value(nil)
        }
    }

    private func updateNonOpenSeaErc1155Balance(contract: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Promise<Void> {
        guard let contractsTokenIdsAndValue = Erc1155TokenIdsFetcher(address: account.address, server: server).readJson() else {
            return .value(())
        }
        return firstly {
            addUnknownErc1155ContractsToDatabase(contractsTokenIdsAndValue: contractsTokenIdsAndValue.tokens, tokens: tokens)
        }.then { (contractsTokenIdsAndValue: Erc1155TokenIds.ContractsTokenIdsAndValues) -> Promise<[TokenIdMetaData]> in
            self.fetchErc1155NonFungibleJsons(contractsTokenIdsAndValue: contractsTokenIdsAndValue, tokens: tokens)
        }.then { (results: [TokenIdMetaData]) -> Promise<Void> in
            self.updateErc1155TokenIdBalancesInDatabase(tokenIdsData: results, tokens: tokens)
        }
        //TODO log error remotely
    }

    private func addUnknownErc1155ContractsToDatabase(contractsTokenIdsAndValue: Erc1155TokenIds.ContractsTokenIdsAndValues, tokens: [Activity.AssignedToken]) -> Promise<Erc1155TokenIds.ContractsTokenIdsAndValues> {
        firstly {
            functional.fetchUnknownErc1155ContractsDetails(contractsTokenIdsAndValue: contractsTokenIdsAndValue, tokens: tokens, server: server, account: account, assetDefinitionStore: assetDefinitionStore)
        }.then(on: .main, { tokensToAdd -> Promise<Erc1155TokenIds.ContractsTokenIdsAndValues> in
            let (promise, seal) = Promise<Erc1155TokenIds.ContractsTokenIdsAndValues>.pending()
            self.tokensDatastore.addCustom(tokens: tokensToAdd, shouldUpdateBalance: false)
            seal.fulfill(contractsTokenIdsAndValue)
            return promise
        })
    }

    private func fetchErc1155NonFungibleJsons(contractsTokenIdsAndValue: Erc1155TokenIds.ContractsTokenIdsAndValues, tokens: [Activity.AssignedToken]) -> Promise<[TokenIdMetaData]> {
        var allGuarantees: [Guarantee<TokenIdMetaData>] = .init()
        for (contract, tokenIdsAndValues) in contractsTokenIdsAndValue {
            let tokenIds = tokenIdsAndValues.keys
            let guarantees: [Guarantee<TokenIdMetaData>] = tokenIds.map { tokenId -> Guarantee<TokenIdMetaData> in
                fetchNonFungibleJson(forTokenId: String(tokenId), address: contract, tokens: tokens).map { jsonString -> TokenIdMetaData in
                    (contract: contract, tokenId: tokenId, json: jsonString, value: tokenIdsAndValues[tokenId]!)
                }
            }
            allGuarantees.append(contentsOf: guarantees)
        }
        return when(fulfilled: allGuarantees)
    }

    private func updateErc1155TokenIdBalancesInDatabase(tokenIdsData: [TokenIdMetaData], tokens: [Activity.AssignedToken]) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()

        var contractsTokenIdsAndValue: [AlphaWallet.Address: [BigUInt: String]] = .init()
        for (contract, tokenId, json, value) in tokenIdsData {
            var tokenIdsAndValue: [BigUInt: String] = contractsTokenIdsAndValue[contract] ?? .init()
            tokenIdsAndValue[tokenId] = json
            contractsTokenIdsAndValue[contract] = tokenIdsAndValue
        }
        for (contract, tokenIdsAndJsons) in contractsTokenIdsAndValue {
            guard let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) else {
                assertImpossibleCodePath(message: "ERC1155 contract: \(contract.eip55String) not found in database when setting balance for 1155")
                return promise
            }
            let jsons: [String] = Array(tokenIdsAndJsons.values)
            tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(jsons))
            tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .type(.erc1155))
        }

        seal.fulfill(())
        return promise
    }

    //Misnomer, we call this "nonFungible", but this includes ERC1155 which can contain (semi-)fungibles, but there's no better name
    private func fetchNonFungibleJson(forTokenId tokenId: String, address: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Guarantee<String> {
        firstly {
            Erc721Contract(server: server).getErc721TokenUri(for: tokenId, contract: address)
        }.then(on: queue, {
            self.fetchTokenJson(forTokenId: tokenId, uri: $0, address: address, tokens: tokens)
        }).recover(on: queue, { _ in
            return self.generateTokenJsonFallback(forTokenId: tokenId, address: address, tokens: tokens)
        })
    }

    private func fetchTokenJson(forTokenId tokenId: String, uri originalUri: URL, address: AlphaWallet.Address, tokens: [TokenObject]) -> Promise<String> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        return firstly {
            //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
            sessionManagerWithDefaultHttpHeaders.request(uri, method: .get).responseData()
        }.map(on: queue, { data, _ in
            if let json = try? JSON(data: data) {
                if json["error"] == "Internal Server Error" {
                    throw Error()
                } else {
                    var jsonDictionary = json
                    if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                        //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                        jsonDictionary["tokenId"] = JSON(tokenId)
                        jsonDictionary["tokenType"] = JSON(TokensDataStore.functional.nonFungibleTokenType(fromTokenType: tokenObject.type).rawValue)
                        jsonDictionary["contractName"] = JSON(tokenObject.name)
                        jsonDictionary["symbol"] = JSON(tokenObject.symbol)
                        jsonDictionary["name"] = JSON(jsonDictionary["name"].stringValue)
                        jsonDictionary["imageUrl"] = JSON(jsonDictionary["image"].string ?? jsonDictionary["image_url"].string ?? "")
                        jsonDictionary["thumbnailUrl"] = jsonDictionary["imageUrl"]
                        //POAP tokens (https://blockscout.com/xdai/mainnet/address/0x22C1f6050E56d2876009903609a2cC3fEf83B415/transactions), eg. https://api.poap.xyz/metadata/2503/278569, use `home_url` as the key for what they should use `external_url` for and they use `external_url` to point back to the token URI
                        jsonDictionary["externalLink"] = JSON(jsonDictionary["home_url"].string ?? jsonDictionary["external_url"].string ?? "")
                    }
                    if let jsonString = jsonDictionary.rawString() {
                        return jsonString
                    } else {
                        throw Error()
                    }
                }
            } else {
                throw Error()
            }
        })
    }

    private func generateTokenJsonFallback(forTokenId tokenId: String, address: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Guarantee<String> {
        var jsonDictionary = JSON()
        if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
            jsonDictionary["tokenId"] = JSON(tokenId)
            jsonDictionary["tokenType"] = JSON(TokensDataStore.functional.nonFungibleTokenType(fromTokenType: tokenObject.type).rawValue)
            jsonDictionary["contractName"] = JSON(tokenObject.name)
            jsonDictionary["decimals"] = JSON(0)
            jsonDictionary["symbol"] = JSON(tokenObject.symbol)
            jsonDictionary["name"] = ""
            jsonDictionary["imageUrl"] = ""
            jsonDictionary["thumbnailUrl"] = ""
            jsonDictionary["externalLink"] = ""
        }
        return .value(jsonDictionary.rawString()!)
    }

    private func fetchTokenJson(forTokenId tokenId: String, uri originalUri: URL, address: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Promise<String> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        return firstly {
            //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
            sessionManagerWithDefaultHttpHeaders.request(uri, method: .get).responseData()
        }.map(on: queue, { data, _ in
            if let json = try? JSON(data: data) {
                if json["error"] == "Internal Server Error" {
                    throw Error()
                } else {
                    var jsonDictionary = json
                    if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                        jsonDictionary["tokenType"] = JSON(TokensDataStore.functional.nonFungibleTokenType(fromTokenType: tokenObject.type).rawValue)
                        //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                        jsonDictionary["contractName"] = JSON(tokenObject.name)
                        jsonDictionary["symbol"] = JSON(tokenObject.symbol)
                        jsonDictionary["tokenId"] = JSON(tokenId)
                        jsonDictionary["decimals"] = JSON(jsonDictionary["decimals"].intValue ?? 0)
                        jsonDictionary["name"] = JSON(jsonDictionary["name"].stringValue)
                        jsonDictionary["imageUrl"] = JSON(jsonDictionary["image"].string ?? jsonDictionary["image_url"].string ?? "")
                        jsonDictionary["thumbnailUrl"] = jsonDictionary["imageUrl"]
                        //POAP tokens (https://blockscout.com/xdai/mainnet/address/0x22C1f6050E56d2876009903609a2cC3fEf83B415/transactions), eg. https://api.poap.xyz/metadata/2503/278569, use `home_url` as the key for what they should use `external_url` for and they use `external_url` to point back to the token URI
                        jsonDictionary["externalLink"] = JSON(jsonDictionary["home_url"].string ?? jsonDictionary["external_url"].string ?? "")
                    }
                    if let jsonString = jsonDictionary.rawString() {
                        return jsonString
                    } else {
                        throw Error()
                    }
                }
            } else {
                throw Error()
            }
        })
    }

    private func updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]], tokens: [Activity.AssignedToken]) -> Promise<[TokenBatchOperation]> {
        return Promise<[TokenBatchOperation]> { seal in
            var actions: [TokenBatchOperation] = []
            for (contract, openSeaNonFungibles) in contractToOpenSeaNonFungibles {
                var listOfJson = [String]()
                var anyNonFungible: OpenSeaNonFungible?
                for each in openSeaNonFungibles {
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

                if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) {
                    switch tokenObject.type {
                    case .nativeCryptocurrency, .erc721, .erc875, .erc721ForTickets, .erc1155:
                        break
                    case .erc20:
                        tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .type(tokenType))
                        actions += [.update(tokenObject: tokenObject, action: .type(tokenType))]
                    }
                    actions += [.update(tokenObject: tokenObject, action: .nonFungibleBalance(listOfJson))]
                    if let anyNonFungible = anyNonFungible {
                        actions += [.update(tokenObject: tokenObject, action: .name(anyNonFungible.contractName))]
                    }
                } else {
                    let token = ERCToken(
                            contract: contract,
                            server: server,
                            name: openSeaNonFungibles[0].contractName,
                            symbol: openSeaNonFungibles[0].symbol,
                            decimals: 0,
                            type: tokenType,
                            balance: listOfJson
                    )

                    actions += [.add(token, shouldUpdateBalance: tokenType.shouldUpdateBalanceWhenDetected)]
                }
            }

            seal.fulfill(actions)
        }
    }

    func writeJsonForTransactions(toUrl url: URL) {
        guard let transactionStorage = erc721TokenIdsFetcher as? TransactionsStorage else { return }
        transactionStorage.writeJsonForTransactions(toUrl: url)
    }
}

extension PrivateBalanceFetcher {
    class functional {}
}

fileprivate extension PrivateBalanceFetcher.functional {
    static func fetchUnknownErc1155ContractsDetails(contractsTokenIdsAndValue: Erc1155TokenIds.ContractsTokenIdsAndValues, tokens: [Activity.AssignedToken], server: RPCServer, account: Wallet, assetDefinitionStore: AssetDefinitionStore) -> Promise<[ERCToken]> {
        let contractsToAdd: [AlphaWallet.Address] = contractsTokenIdsAndValue.keys.filter { contract in
            !tokens.contains(where: { $0.contractAddress.sameContract(as: contract)})
        }

        guard !contractsToAdd.isEmpty else {
            return Promise<[ERCToken]>.value(.init())
        }

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
                            server: server,
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
// swiftlint:enable type_body_length
