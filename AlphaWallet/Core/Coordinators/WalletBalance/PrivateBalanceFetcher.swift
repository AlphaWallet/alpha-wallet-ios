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
        return TokenProvider(account: account, server: server, queue: backgroundQueue)
    }()

    private let account: Wallet

    private let openSea: OpenSea
    private let backgroundQueue: DispatchQueue
    private let server: RPCServer
    private lazy var etherToken = Activity.AssignedToken(tokenObject: TokensDataStore.etherToken(forServer: server))
    private var isRefeshingBalance: Bool = false
    weak var delegate: PrivateTokensDataStoreDelegate?
    private var enabledObjectsObservation: NotificationToken?
    private let tokensDatastore: PrivateTokensDatastoreType
    private let assetDefinitionStore: AssetDefinitionStore

    init(account: Wallet, tokensDatastore: PrivateTokensDatastoreType, server: RPCServer, assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue) {
        self.account = account
        self.server = server
        self.backgroundQueue = queue
        self.openSea = OpenSea.createInstance(forServer: server)
        self.tokensDatastore = tokensDatastore
        self.assetDefinitionStore = assetDefinitionStore
        //NOTE: fire refresh balance only for initial scope, and while adding new tokens
        enabledObjectsObservation = tokensDatastore.enabledObjects.observe(on: backgroundQueue) { [weak self] change in
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
        let tokenObjects = tokensDatastore.enabledObjects.map { Activity.AssignedToken(tokenObject: $0) }
        refreshBalance(tokenObjects: Array(tokenObjects), updatePolicy: .all, force: false)
    }

    private func refreshBalanceForNonErc721Or1155Tokens(tokens: [Activity.AssignedToken], group: DispatchGroup) {
        assert(!tokens.contains { $0.isERC721Or1155AndNotForTickets })

        for tokenObject in tokens {
            group.enter()

            refreshBalanceForNonErc721Or1155Tokens(forToken: tokenObject, tokensDatastore: tokensDatastore) { [weak self] balanceValueHasChange in
                guard let strongSelf = self, let delegate = strongSelf.delegate else {
                    group.leave()
                    return
                }

                if let value = balanceValueHasChange, value {
                    delegate.didUpdate(in: strongSelf)
                }

                group.leave()
            }
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

        switch updatePolicy {
        case .all:
            refreshEthBalance(etherToken: etherToken, group: group)
            refreshBalance(tokenObjects: tokenObjects, group: group)
        case .ercTokens:
            refreshBalance(tokenObjects: tokenObjects, group: group)
        case .eth:
            refreshEthBalance(etherToken: etherToken, group: group)
        }

        group.notify(queue: backgroundQueue) {
            self.isRefeshingBalance = false
        }
    }

    private func refreshEthBalance(etherToken: Activity.AssignedToken, group: DispatchGroup) {
        let tokensDatastore = self.tokensDatastore
        group.enter()
        tokenProvider.getEthBalance(for: account.address) { [weak self] result in
            switch result {
            case .success(let balance):
                tokensDatastore.update(primaryKey: etherToken.primaryKey, action: .value(balance.value)) { balanceValueHasChange in
                    guard let strongSelf = self, let delegate = strongSelf.delegate else {
                        group.leave()
                        return
                    }

                    if let value = balanceValueHasChange, value {
                        delegate.didUpdate(in: strongSelf)
                    }

                    group.leave()
                }
            case .failure:
                group.leave()
            }
        }
    }

    private func refreshBalance(tokenObjects: [Activity.AssignedToken], group: DispatchGroup) {
        let updateTokens = tokenObjects.filter { $0 != etherToken }

        let notErc721Or1155Tokens = updateTokens.filter { !$0.isERC721Or1155AndNotForTickets }
        let erc721Or1155Tokens = updateTokens.filter { $0.isERC721Or1155AndNotForTickets }

        refreshBalanceForNonErc721Or1155Tokens(tokens: notErc721Or1155Tokens, group: group)
        refreshBalanceForErc721Or1155Tokens(tokens: erc721Or1155Tokens, group: group)
    }

    private func refreshBalanceForNonErc721Or1155Tokens(forToken tokenObject: Activity.AssignedToken, tokensDatastore: PrivateTokensDatastoreType, completion: @escaping (Bool?) -> Void) {
        switch tokenObject.type {
        case .nativeCryptocurrency:
            completion(nil)
        case .erc20:
            tokenProvider.getERC20Balance(for: tokenObject.contractAddress, completion: { result in
                switch result {
                case .success(let balance):
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .value(balance), completion: completion)
                case .failure:
                    completion(nil)
                }
            })
        case .erc875:
            tokenProvider.getERC875Balance(for: tokenObject.contractAddress, completion: { result in
                switch result {
                case .success(let balance):
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(balance), completion: completion)
                case .failure:
                    completion(nil)
                }
            })
        case .erc721, .erc1155:
            break
        case .erc721ForTickets:
            tokenProvider.getERC721ForTicketsBalance(for: tokenObject.contractAddress, completion: { result in
                switch result {
                case .success(let balance):
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(balance), completion: completion)
                case .failure:
                    completion(nil)
                }
            })
        }
    }

    private func refreshBalanceForErc721Or1155Tokens(tokens: [Activity.AssignedToken], group: DispatchGroup) {
        assert(!tokens.contains { !$0.isERC721Or1155AndNotForTickets })
        firstly {
            getTokensFromOpenSea()
        }.done { [weak self] contractToOpenSeaNonFungibles in
            guard let strongSelf = self else { return }
            let erc721Or1155ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721Or1155ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721Or1155ContractsFoundInOpenSea
            strongSelf.updateNonOpenSeaNonFungiblesBalance(contracts: erc721Or1155ContractsNotFoundInOpenSea, tokens: tokens, group: group)
            strongSelf.updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, tokens: tokens, group: group)
        }.cauterize()
    }

    private func updateNonOpenSeaNonFungiblesBalance(contracts: [AlphaWallet.Address], tokens: [Activity.AssignedToken], group: DispatchGroup) {
        let promises = contracts.map { updateNonOpenSeaNonFungiblesBalance(erc721Or1115ContractNotFoundInOpenSea: $0, tokens: tokens, tokensDatastore: tokensDatastore) }
        group.enter()

        firstly {
            when(resolved: promises)
        }.done { _ in
            group.leave()
        }
    }

    private func updateNonOpenSeaNonFungiblesBalance(erc721Or1115ContractNotFoundInOpenSea contract: AlphaWallet.Address, tokens: [Activity.AssignedToken], tokensDatastore: PrivateTokensDatastoreType) -> Promise<Void> {
        let erc721Promise = updateNonOpenSeaErc721Balance(contract: contract, tokens: tokens, tokensDatastore: tokensDatastore)
        let erc1155Promise: Promise<Void> = Promise.value(())
        return firstly {
            when(fulfilled: erc721Promise, erc1155Promise)
        }.map { _, _ in
            //no-op
        }.asVoid()
    }

    private func updateNonOpenSeaErc721Balance(contract: AlphaWallet.Address, tokens: [Activity.AssignedToken], tokensDatastore: PrivateTokensDatastoreType) -> Promise<Void> {
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher else { return Promise { _ in } }
        return firstly {
            erc721TokenIdsFetcher.tokenIdsForErc721Token(contract: contract, inAccount: account.address)
        }.then { tokenIds -> Promise<[String]> in
            let guarantees: [Guarantee<String>] = tokenIds.map { self.fetchNonFungibleJson(forTokenId: $0, address: contract, tokens: tokens) }
            return when(fulfilled: guarantees)
        }.then { jsons -> Promise<Void> in
            return Promise<Void> { seal in
                guard let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) else {
                    seal.fulfill(())
                    return
                }
                tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(jsons)) { _ in
                    seal.fulfill(())
                }
            }
        }.asVoid()
    }

    private func updateNonOpenSeaErc1155Balance(contract: AlphaWallet.Address, tokens: [Activity.AssignedToken], tokensDatastore: PrivateTokensDatastoreType) -> Promise<Void> {
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
        }.then { tokensToAdd -> Promise<Erc1155TokenIds.ContractsTokenIdsAndValues> in
            let (promise, seal) = Promise<Erc1155TokenIds.ContractsTokenIdsAndValues>.pending()
            self.tokensDatastore.addCustom(tokens: tokensToAdd, shouldUpdateBalance: false) {
                seal.fulfill(contractsTokenIdsAndValue)
            }
            return promise
        }
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
        let group: DispatchGroup = .init()
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
            group.enter()
            tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(jsons)) { _ in
                group.leave()
            }
            group.enter()
            tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .type(.erc1155)) { _ in
                group.leave()
            }
        }
        group.notify(queue: .main) {
            seal.fulfill(())
        }
        return promise
    }

    //Misnomer, we call this "nonFungible", but this includes ERC1155 which can contain (semi-)fungibles, but there's no better name
    private func fetchNonFungibleJson(forTokenId tokenId: String, address: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Guarantee<String> {
        firstly {
            Erc721Contract(server: server).getErc721TokenUri(for: tokenId, contract: address)
        }.then {
            self.fetchTokenJson(forTokenId: tokenId, uri: $0, address: address, tokens: tokens)
        }.recover { e in
            return self.generateTokenJsonFallback(forTokenId: tokenId, address: address, tokens: tokens)
        }
    }

    private func fetchTokenJson(forTokenId tokenId: String, uri originalUri: URL, address: AlphaWallet.Address, tokens: [TokenObject]) -> Promise<String> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        return firstly {
            //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
            sessionManagerWithDefaultHttpHeaders.request(uri, method: .get).responseData()
        }.map { data, _ in
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
        }
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
        }.map { data, _ in
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
        }
    }

    private func updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]], tokens: [Activity.AssignedToken], group: DispatchGroup) {
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
                    group.enter()
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .type(tokenType)) { _ in group.leave() }
                }
                group.enter()
                tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(listOfJson)) { _ in group.leave() }
                if let anyNonFungible = anyNonFungible {
                    group.enter()
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .name(anyNonFungible.contractName)) { _ in group.leave() }
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
                group.enter()
                tokensDatastore.addCustom(token: token, shouldUpdateBalance: tokenType.shouldUpdateBalanceWhenDetected) { group.leave() }
            }
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
