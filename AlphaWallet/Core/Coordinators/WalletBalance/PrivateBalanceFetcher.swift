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
import SwiftyJSON
import Combine

protocol PrivateTokensDataStoreDelegate: AnyObject {
    func didUpdate(in tokensDataStore: PrivateBalanceFetcher)
    func didAddToken(in tokensDataStore: PrivateBalanceFetcher)
}

protocol PrivateBalanceFetcherType: AnyObject {
    var delegate: PrivateTokensDataStoreDelegate? { get set }
    var erc721TokenIdsFetcher: Erc721TokenIdsFetcher? { get set }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
}

// swiftlint:disable type_body_length
class PrivateBalanceFetcher: PrivateBalanceFetcherType {
    typealias TokenIdMetaData = (contract: AlphaWallet.Address, tokenId: BigUInt, json: String)

    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private var sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()
    weak var erc721TokenIdsFetcher: Erc721TokenIdsFetcher?

    private let account: Wallet
    let openSea: OpenSea
    private let queue: DispatchQueue
    private let server: RPCServer
    private lazy var etherToken = Activity.AssignedToken(tokenObject: MultipleChainsTokensDataStore.functional.etherToken(forServer: server))
    private var isRefeshingBalance: Bool = false
    weak var delegate: PrivateTokensDataStoreDelegate?
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let enjin: EnjinProvider
    private var cachedErc1155TokenIdsFetchers: [AddressAndRPCServer: Erc1155TokenIdsFetcher] = [:]
    private var cancelable = Set<AnyCancellable>()
    private let keystore: Keystore

    init(account: Wallet, keystore: Keystore, tokensDataStore: TokensDataStore, server: RPCServer, assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue) {
        self.keystore = keystore
        self.account = account
        self.server = server
        self.queue = queue
        self.openSea = OpenSea.createInstance(with: AddressAndRPCServer(address: account.address, server: server), keystore: keystore)
        self.enjin = EnjinProvider.createInstance(with: AddressAndRPCServer(address: account.address, server: server))
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore

        // NOTE: fire refresh balance only for initial scope, and while adding new tokens
        tokensDataStore
            .enabledTokenObjectsChangesetPublisher(forServers: [server])
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] changeset in
                guard let strongSelf = self else { return }
                switch changeset {
                case .initial(let tokenObjects):
                    let tokenObjects = tokenObjects.map { Activity.AssignedToken(tokenObject: $0) }

                    strongSelf.refreshBalance(tokenObjects: Array(tokenObjects), updatePolicy: .all, force: true).done { _ in
                            // no-op
                    }.cauterize()
                case .update(let tokenObjects, _, let insertions, _):
                    let tokenObjects = insertions.map { tokenObjects[$0] }.map { Activity.AssignedToken(tokenObject: $0) }
                    guard !tokenObjects.isEmpty else { return }

                    strongSelf.refreshBalance(tokenObjects: tokenObjects, updatePolicy: .all, force: true).done { _ in
                        // no-op
                    }.cauterize()

                    strongSelf.delegate?.didAddToken(in: strongSelf)
                case .error:
                    break
                }
            }.store(in: &cancelable)
    }

    // NOTE: Its important to return value for promise and not an error. As we are using `when(fulfilled: ...)`. There is force unwrap inside the `when(fulfilled` function
    private func getTokensFromEnjin() -> Promise<EnjinSemiFungibleTokens> {
        return enjin.makeFetchPromise()
            .map({ mapped -> EnjinSemiFungibleTokens in
                var result: EnjinSemiFungibleTokens = [:]
                let tokens = Array(mapped.values.flatMap { $0 })
                for each in tokens {
                    guard let tokenId = each.id else { continue }
                    // NOTE: store with trailing zeros `70000000000019a4000000000000000000000000000000000000000000000000` instead of `70000000000019a4`
                    result[TokenIdConverter.addTrailingZerosPadding(string: tokenId)] = each
                }

                return result
            }).recover { _ -> Promise<EnjinSemiFungibleTokens> in
                return .value([:])
            }
    }

    private func getTokensFromOpenSea() -> Promise<OpenSeaNonFungiblesToAddress> {
        // TODO when we no longer create multiple instances of TokensDataStore, we don't have to use singleton for OpenSea class. This was to avoid fetching multiple times from OpenSea concurrently
        // NOTE: We need to reduce amount of concurrent calls to Open Sea, because of call trolling of OpenSea, that is why we make calls only for current wallet
        guard keystore.currentWallet.address == account.address else {
            return .value([:])
        }
        return openSea.makeFetchPromise()
            .recover { _ -> Promise<OpenSeaNonFungiblesToAddress> in
                return .value([:])
            }
    }

    func refreshBalance(updatePolicy: RefreshBalancePolicy, force: Bool = false) -> Promise<Void> {
        Promise<[Activity.AssignedToken]> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let tokenObjects = strongSelf.tokensDataStore
                    .enabledTokenObjects(forServers: [strongSelf.server])
                    .map { Activity.AssignedToken(tokenObject: $0) }

                seal.fulfill(tokenObjects)
            }
        }.then(on: queue, { tokenObjects in
            return self.refreshBalance(tokenObjects: tokenObjects, updatePolicy: .all, force: force)
        }).recover(on: queue, { e -> Promise<Void> in
            error(value: e)
            throw e
        })
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

    private func refreshBalance(tokenObjects: [Activity.AssignedToken], updatePolicy: RefreshBalancePolicy, force: Bool = false) -> Promise<Void> {
        guard !isRefeshingBalance || force else { return .value(()) }

        isRefeshingBalance = true
        var promises: [Promise<Bool?>] = []

        switch updatePolicy {
        case .all:
            promises += [refreshEthBalance(etherToken: etherToken)]
            promises += [refreshBalance(tokenObjects: tokenObjects)]
        case .ercTokens:
            promises += [refreshBalance(tokenObjects: tokenObjects)]
        case .eth:
            promises += [refreshEthBalance(etherToken: etherToken)]
        }

        return firstly {
            when(resolved: promises).map(on: queue, { values -> Bool? in
                //NOTE: taking for first element means that values was updated
                return values.compactMap { $0.optionalValue }.compactMap { $0 }.first
            })
        }.ensure({
            self.isRefeshingBalance = false
        }).get(on: queue, { balanceValueHasChange in
            if let value = balanceValueHasChange, value {
                self.delegate?.didUpdate(in: self)
            }
        }).asVoid()
    }

    private func refreshEthBalance(etherToken: Activity.AssignedToken) -> Promise<Bool?> {
        let tokensDataStore = self.tokensDataStore

        return TokenProvider(account: account, server: server, queue: queue)
            .getEthBalance(for: account.address)
            .then(on: .main, { balance -> Promise<Bool?> in
                let tokenHasUpdated = tokensDataStore.updateToken(primaryKey: etherToken.primaryKey, action: .value(balance.value))
                return .value(tokenHasUpdated)
            }).recover(on: queue, { _ -> Guarantee<Bool?> in
                return .value(nil)
            })
    }

    private func refreshBalance(tokenObjects: [Activity.AssignedToken]) -> Promise<Bool?> {
        let updateTokens = tokenObjects.filter { $0 != etherToken }

        let notErc721Or1155Tokens = updateTokens.filter { !$0.isERC721Or1155AndNotForTickets }
        let erc721Or1155Tokens = updateTokens.filter { $0.isERC721Or1155AndNotForTickets }

        let promise1 = refreshBalanceForNonErc721Or1155Tokens(tokens: notErc721Or1155Tokens)
        let promise2 = refreshBalanceForErc721Or1155Tokens(tokens: erc721Or1155Tokens)
        let tokensDatastore = self.tokensDataStore

        return when(resolved: [promise1, promise2])
            .then(on: .main, { value -> Promise<Bool?> in
                let resolved: [TokenBatchOperation] = value.compactMap { $0.optionalValue }.flatMap { $0 }
                let result = tokensDatastore.batchUpdateTokenPromise(resolved)
                return .value(result)
            })
    }

    enum TokenBatchOperation {
        case add(ERCToken, shouldUpdateBalance: Bool)
        case update(tokenObject: Activity.AssignedToken, action: TokenUpdateAction)

        var updateAction: TokenUpdateAction? {
            switch self {
            case .add:
                return nil
            case .update(_, let action):
                return action
            }
        }
    }

    private func getBalanceForNonErc721Or1155Tokens(forToken tokenObject: Activity.AssignedToken) -> Promise<TokenBatchOperation?> {
        switch tokenObject.type {
        case .nativeCryptocurrency, .erc721, .erc1155:
            return .value(nil)
        case .erc20:
            return TokenProvider(account: account, server: server, queue: queue)
                .getERC20Balance(for: tokenObject.contractAddress)
                .map(on: queue, { value -> TokenBatchOperation in
                    return .update(tokenObject: tokenObject, action: .value(value))
                }).recover { _ -> Promise<TokenBatchOperation?> in
                    return .value(nil)
                }
        case .erc875:
            return TokenProvider(account: account, server: server, queue: queue)
                .getERC875Balance(for: tokenObject.contractAddress)
                .map(on: queue, { balance -> TokenBatchOperation in
                    return .update(tokenObject: tokenObject, action: .nonFungibleBalance(balance))
                }).recover { _ -> Promise<TokenBatchOperation?> in
                    return .value(nil)
                }
        case .erc721ForTickets:
            return TokenProvider(account: account, server: server, queue: queue)
                .getERC721ForTicketsBalance(for: tokenObject.contractAddress)
                .map(on: queue, { balance -> TokenBatchOperation in
                    return .update(tokenObject: tokenObject, action: .nonFungibleBalance(balance))
                }).recover { _ -> Promise<TokenBatchOperation?> in
                    return .value(nil)
                }
        }
    }
    typealias EnjinSemiFungibleTokens = [String: GetEnjinTokenQuery.Data.EnjinToken]

    private func refreshBalanceForErc721Or1155Tokens(tokens: [Activity.AssignedToken]) -> Promise<[PrivateBalanceFetcher.TokenBatchOperation]> {
        assert(!tokens.contains { !$0.isERC721Or1155AndNotForTickets })

        let tokensFromOpenSeaPromise = getTokensFromOpenSea()
        let enjinTokensPromise = getTokensFromEnjin()
        let queue = queue
        let account = account
        let server = server

        return firstly {
            when(fulfilled: tokensFromOpenSeaPromise, enjinTokensPromise)
        }.then(on: queue, { [weak self] response -> Guarantee<[PrivateBalanceFetcher.TokenBatchOperation]> in
            guard let strongSelf = self else { return .value([]) }

            let contractToOpenSeaNonFungibles = response.0
            let enjinTokens = response.1

            let erc721Or1155ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721Or1155ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721Or1155ContractsFoundInOpenSea
            let p1 = strongSelf.updateNonOpenSeaNonFungiblesBalance(contracts: erc721Or1155ContractsNotFoundInOpenSea, tokens: tokens, enjinTokens: enjinTokens, queue: queue)
            let p2 = PrivateBalanceFetcher.functional.updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, tokens: tokens, enjinTokens: enjinTokens, server: server, account: account)

            return when(resolved: [p1, p2]).map(on: queue, { results -> [PrivateBalanceFetcher.TokenBatchOperation] in
                return results.compactMap { $0.optionalValue }.flatMap { $0 }
            })
        })
    }

    private func updateNonOpenSeaNonFungiblesBalance(contracts: [AlphaWallet.Address], tokens: [Activity.AssignedToken], enjinTokens: EnjinSemiFungibleTokens, queue: DispatchQueue) -> Promise<[PrivateBalanceFetcher.TokenBatchOperation]> {
        let erc721Contracts = filterAwayErc1155Tokens(contracts: contracts)
        let erc721Promises: [Promise<[TokenBatchOperation]>] = erc721Contracts
            .map { updateNonOpenSeaErc721Balance(contract: $0, tokens: tokens).map { $0 == nil ? [] : [$0!] } }
        let erc1155Promise: Promise<[TokenBatchOperation]> = updateNonOpenSeaErc1155Balance(tokens: tokens, enjinTokens: enjinTokens, queue: queue)
        return firstly {
            when(fulfilled: erc721Promises + [erc1155Promise])
        }.map(on: queue, { results in
            results.compactMap { $0 }.flatMap { $0 }
        })
    }
    //NOTE: avoid memory leak while creating a lot of `Erc1155TokenIdsFetcher` instances
    private func createOrGetErc1155TokenIdsFetcher(address: AlphaWallet.Address, server: RPCServer) -> Erc1155TokenIdsFetcher {
        let key = AddressAndRPCServer(address: address, server: server)
        if let value = cachedErc1155TokenIdsFetchers[key] {
            return value
        } else {
            let fetcher = Erc1155TokenIdsFetcher(address: account.address, server: server, queue: queue)
            cachedErc1155TokenIdsFetchers[key] = fetcher

            return fetcher
        }
    }

    private func filterAwayErc1155Tokens(contracts: [AlphaWallet.Address]) -> [AlphaWallet.Address] {
        if let erc1155Contracts = createOrGetErc1155TokenIdsFetcher(address: account.address, server: server).knownErc1155Contracts() {
            return contracts.filter { !erc1155Contracts.contains($0) }
        } else {
            return contracts
        }
    }

    private func updateNonOpenSeaErc721Balance(contract: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Promise<TokenBatchOperation?> {
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher else { return .value(nil) }
        return firstly {
            erc721TokenIdsFetcher.tokenIdsForErc721Token(contract: contract, forServer: server, inAccount: account.address)
        }.then(on: queue, { tokenIds -> Promise<[String]> in
            let guarantees: [Guarantee<String>] = tokenIds
                .map { self.fetchNonFungibleJson(forTokenId: $0, tokenType: .erc721, address: contract, tokens: tokens, enjinTokens: [:]) }
            return when(fulfilled: guarantees)
        }).map(on: queue, { jsons -> TokenBatchOperation? in
            guard let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) else {
                return nil
            }
            return .update(tokenObject: tokenObject, action: .nonFungibleBalance(jsons))
        }).recover({ _ -> Guarantee<TokenBatchOperation?> in
            return .value(nil)
        })
    }

    private func updateNonOpenSeaErc1155Balance(tokens: [Activity.AssignedToken], enjinTokens: EnjinSemiFungibleTokens, queue: DispatchQueue) -> Promise<[TokenBatchOperation]> {
        guard Features.isErc1155Enabled else { return .value([]) }
        //Local copies so we don't access the wrong ones during async operation
        let account = self.account
        let server = self.server

        let fetcher = createOrGetErc1155TokenIdsFetcher(address: account.address, server: server)

        return firstly {
            fetcher.detectContractsAndTokenIds()
        }.then(on: queue, { contractsAndTokenIds in
            self.addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: contractsAndTokenIds.tokens, tokens: tokens)
        }).then(on: queue, { (contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds) -> Promise<(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokenIdMetaDatas: [TokenIdMetaData])> in
                self.fetchErc1155NonFungibleJsons(contractsAndTokenIds: contractsAndTokenIds, tokens: tokens, enjinTokens: enjinTokens)
                    .map { (contractsAndTokenIds: contractsAndTokenIds, tokenIdMetaDatas: $0) }
        }).then(on: queue, { (contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokenIdMetaDatas: [TokenIdMetaData]) -> Promise<[TokenBatchOperation]> in
            let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractsAndTokenIds
                .mapValues { tokenIds -> [BigInt] in
                    tokenIds.compactMap { BigInt($0) }
                }
            let promises = contractsToTokenIds.map { contract, tokenIds in
                Erc1155BalanceFetcher(address: account.address, server: server)
                    .fetch(contract: contract, tokenIds: Set(tokenIds))
                    .map { (contract: contract, balances: $0 ) }
            }
            return firstly {
                when(fulfilled: promises)
            }.map(on: queue, { (contractsAndBalances: [(contract: AlphaWallet.Address, balances: [BigInt: BigUInt])]) in
                var contractToTokenIds: [AlphaWallet.Address: [NonFungibleFromTokenUri]] = .init()
                for each in tokenIdMetaDatas {
                    guard let data = each.json.data(using: .utf8) else { continue }
                    guard let nonFungible = nonFungible(fromJsonData: data, tokenType: .erc1155) as? NonFungibleFromTokenUri else { continue }
                    var nonFungibles = contractToTokenIds[each.contract] ?? .init()
                    nonFungibles.append(nonFungible)
                    contractToTokenIds[each.contract] = nonFungibles
                }
                return functional.fillErc1155NonFungiblesWithBalance(contractToNonFungibles: contractToTokenIds, contractsAndBalances: contractsAndBalances)
            }).map(on: queue, { contractToOpenSeaNonFungiblesWithUpdatedBalances in
                functional.buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToOpenSeaNonFungiblesWithUpdatedBalances as [AlphaWallet.Address: [NonFungibleFromTokenUri]], server: server, tokens: tokens)
            })
        })
        //TODO log error remotely
    }

    private func addUnknownErc1155ContractsToDatabase(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokens: [Activity.AssignedToken]) -> Promise<Erc1155TokenIds.ContractsAndTokenIds> {
        let tokensDatastore = self.tokensDataStore
        return firstly {
            functional.fetchUnknownErc1155ContractsDetails(contractsAndTokenIds: contractsAndTokenIds, tokens: tokens, server: server, account: account, assetDefinitionStore: assetDefinitionStore)
        }.then(on: .main, { tokensToAdd -> Promise<Erc1155TokenIds.ContractsAndTokenIds> in
            tokensDatastore.addCustom(tokens: tokensToAdd, shouldUpdateBalance: false)

            return .value(contractsAndTokenIds)
        })
    }

    private func fetchErc1155NonFungibleJsons(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokens: [Activity.AssignedToken], enjinTokens: EnjinSemiFungibleTokens) -> Promise<[TokenIdMetaData]> {
        var allGuarantees: [Guarantee<TokenIdMetaData>] = .init()
        for (contract, tokenIds) in contractsAndTokenIds {
            let guarantees: [Guarantee<TokenIdMetaData>] = tokenIds.map { tokenId -> Guarantee<TokenIdMetaData> in
                fetchNonFungibleJson(forTokenId: String(tokenId), tokenType: .erc1155, address: contract, tokens: tokens, enjinTokens: enjinTokens).map(on: queue, { jsonString -> TokenIdMetaData in
                    return (contract: contract, tokenId: tokenId, json: jsonString)
                })
            }
            allGuarantees.append(contentsOf: guarantees)
        }
        return when(fulfilled: allGuarantees)
    }

    //Misnomer, we call this "nonFungible", but this includes ERC1155 which can contain (semi-)fungibles, but there's no better name
    private func fetchNonFungibleJson(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address, tokens: [Activity.AssignedToken], enjinTokens: EnjinSemiFungibleTokens) -> Guarantee<String> {
        firstly {
            NonFungibleContract(server: server).getTokenUri(for: tokenId, contract: address)
        }.then(on: queue, {
            self.fetchTokenJson(forTokenId: tokenId, tokenType: tokenType, uri: $0, address: address, tokens: tokens, enjinTokens: enjinTokens)
        }).recover(on: queue, { _ in
            return PrivateBalanceFetcher.functional.generateTokenJsonFallback(forTokenId: tokenId, tokenType: tokenType, address: address, tokens: tokens)
        })
    }

    private func fetchTokenJson(forTokenId tokenId: String, tokenType: TokenType, uri originalUri: URL, address: AlphaWallet.Address, tokens: [Activity.AssignedToken], enjinTokens: EnjinSemiFungibleTokens) -> Promise<String> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        //TODO check this doesn't print duplicates, including unnecessary fetches
        verboseLog("Fetching token URI: \(originalUri.absoluteString)… with: \(uri.absoluteString)")

        return firstly {
            //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
            sessionManagerWithDefaultHttpHeaders.request(uri, method: .get).responseData(queue: queue)
        }.map(on: queue, { (data, _) -> String in
            if let json = try? JSON(data: data) {
                if let errorMessage = json["error"].string {
                    verboseLog("Fetched token URI: \(originalUri.absoluteString) error: \(errorMessage)")
                }
                if json["error"] == "Internal Server Error" {
                    throw Error()
                } else {
                    verboseLog("Fetched token URI: \(originalUri.absoluteString)")
                    var jsonDictionary = json
                    if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                        jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
                        //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                        jsonDictionary["contractName"] = JSON(tokenObject.name)
                        jsonDictionary["symbol"] = JSON(tokenObject.symbol)
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
    func writeJsonForTransactions(toUrl url: URL) {
        guard let transactionStorage = erc721TokenIdsFetcher as? TransactionsStorage else { return }
        transactionStorage.writeJsonForTransactions(toUrl: url)
    }
}
// swiftlint:enable type_body_length

extension PrivateBalanceFetcher {
    class functional {}
}

fileprivate extension PrivateBalanceFetcher.functional {

    static func generateTokenJsonFallback(forTokenId tokenId: String, tokenType: TokenType, address: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Guarantee<String> {
        var jsonDictionary = JSON()
        if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
            jsonDictionary["tokenId"] = JSON(tokenId)
            jsonDictionary["tokenType"] = JSON(tokenType.rawValue)
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

    static func updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]], tokens: [Activity.AssignedToken], enjinTokens: PrivateBalanceFetcher.EnjinSemiFungibleTokens, server: RPCServer, account: Wallet) -> Promise<[PrivateBalanceFetcher.TokenBatchOperation]> {
        var erc1155ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.tokenType == .erc1155 }
        //All non-ERC1155 to be defensive
        let nonErc1155ContractToOpenSeaNonFungibles = contractToOpenSeaNonFungibles.filter { $0.value.randomElement()?.tokenType != .erc1155 }

        func _buildErc1155Updater(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]]) -> Promise<[PrivateBalanceFetcher.TokenBatchOperation]> {
            let contractsToTokenIds: [AlphaWallet.Address: [BigInt]] = contractToOpenSeaNonFungibles.mapValues { openSeaNonFungibles -> [BigInt] in
                openSeaNonFungibles.compactMap { BigInt($0.tokenId) }
            }
            //OpenSea API output doesn't include the balance ("value") for each tokenId, it seems. So we have to fetch them:
            let promises = contractsToTokenIds.map { contract, tokenIds in
                Erc1155BalanceFetcher(address: account.address, server: server)
                    .fetch(contract: contract, tokenIds: Set(tokenIds))
                    .map { (contract: contract, balances: $0) }
            }
            return firstly {
                when(fulfilled: promises)
            }.map { (contractsAndBalances: [(contract: AlphaWallet.Address, balances: [BigInt: BigUInt])]) in
                fillErc1155NonFungiblesWithBalance(contractToNonFungibles: contractToOpenSeaNonFungibles, contractsAndBalances: contractsAndBalances)
            }.map { contractToOpenSeaNonFungiblesWithUpdatedBalances in
                buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToOpenSeaNonFungiblesWithUpdatedBalances, server: server, tokens: tokens)
            }
        }

        func _buildNonErc1155Updater(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]]) -> [PrivateBalanceFetcher.TokenBatchOperation] {
            buildUpdateNonFungiblesBalanceActions(contractToNonFungibles: contractToOpenSeaNonFungibles, server: server, tokens: tokens)
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

        return firstly {
            _buildErc1155Updater(contractToOpenSeaNonFungibles: erc1155ContractToOpenSeaNonFungibles)
        }.map {
            $0 + _buildNonErc1155Updater(contractToOpenSeaNonFungibles: nonErc1155ContractToOpenSeaNonFungibles)
        }
    }

    static func fetchUnknownErc1155ContractsDetails(contractsAndTokenIds: Erc1155TokenIds.ContractsAndTokenIds, tokens: [Activity.AssignedToken], server: RPCServer, account: Wallet, assetDefinitionStore: AssetDefinitionStore) -> Promise<[ERCToken]> {
        let contractsToAdd: [AlphaWallet.Address] = contractsAndTokenIds.keys.filter { contract in
            !tokens.contains(where: { $0.contractAddress.sameContract(as: contract) })
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

    static func buildUpdateNonFungiblesBalanceActions<T: NonFungibleFromJson>(contractToNonFungibles: [AlphaWallet.Address: [T]], server: RPCServer, tokens: [Activity.AssignedToken]) -> [PrivateBalanceFetcher.TokenBatchOperation] {
        var actions: [PrivateBalanceFetcher.TokenBatchOperation] = []
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
            if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) {
                actions += [
                    .update(tokenObject: tokenObject, action: .type(tokenType)),
                    .update(tokenObject: tokenObject, action: .nonFungibleBalance(listOfJson)),
                ]
                if let anyNonFungible = anyNonFungible {
                    actions += [.update(tokenObject: tokenObject, action: .name(anyNonFungible.contractName))]
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
