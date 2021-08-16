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
    static let fetchContractDataTimeout = TimeInterval(4)
    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private var sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()
    weak var erc721TokenIdsFetcher: Erc721TokenIdsFetcher?

    private lazy var getNativeCryptoCurrencyBalanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator = {
        return GetNativeCryptoCurrencyBalanceCoordinator(forServer: server, queue: backgroundQueue)
    }()

    private lazy var getERC20BalanceCoordinator: GetERC20BalanceCoordinator = {
        return GetERC20BalanceCoordinator(forServer: server, queue: backgroundQueue)
    }()

    private lazy var getERC875BalanceCoordinator: GetERC875BalanceCoordinator = {
        return GetERC875BalanceCoordinator(forServer: server, queue: backgroundQueue)
    }()

    private lazy var getERC721ForTicketsBalanceCoordinator: GetERC721ForTicketsBalanceCoordinator = {
        return GetERC721ForTicketsBalanceCoordinator(forServer: server, queue: backgroundQueue)
    }()

    private lazy var getERC721BalanceCoordinator: GetERC721BalanceCoordinator = {
        return GetERC721BalanceCoordinator(forServer: server, queue: backgroundQueue)
    }()

    private let account: Wallet
    private let numberOfTimesToRetryFetchContractData = 2

    private var chainId: Int {
        return server.chainID
    }

    private let openSea: OpenSea
    private let backgroundQueue: DispatchQueue
    private let server: RPCServer
    private lazy var etherToken = Activity.AssignedToken(tokenObject: TokensDataStore.etherToken(forServer: server))
    private var isRefeshingBalance: Bool = false
    weak var delegate: PrivateTokensDataStoreDelegate?
    private var enabledObjectsObservation: NotificationToken?

    private let tokensDatastore: PrivateTokensDatastoreType

    init(account: Wallet, tokensDatastore: PrivateTokensDatastoreType, server: RPCServer, queue: DispatchQueue) {
        self.account = account
        self.server = server
        self.backgroundQueue = queue
        self.openSea = OpenSea.createInstance(forServer: server)
        self.tokensDatastore = tokensDatastore
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

    private func getERC20Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC20BalanceCoordinator.getBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    private func getERC875Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC875BalanceCoordinator.getERC875TokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    private func getERC721ForTicketsBalance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC721ForTicketsBalanceCoordinator.getERC721ForTicketsTokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    private func getERC721Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC721BalanceCoordinator.getERC721TokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success(let balance):
                    if balance >= Int.max {
                        completion(.failure(AnyError(Web3Error(description: ""))))
                    } else {
                        completion(.success([String](repeating: "0", count: Int(balance))))
                    }
                case .failure(let error):
                    if !triggerRetry() {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    private func getTokensFromOpenSea() -> OpenSea.PromiseResult {
        //TODO when we no longer create multiple instances of TokensDataStore, we don't have to use singleton for OpenSea class. This was to avoid fetching multiple times from OpenSea concurrently
        return openSea.makeFetchPromise(forOwner: account.address)
    }

    func refreshBalance(updatePolicy: RefreshBalancePolicy, force: Bool = false) {
        let tokenObjects = tokensDatastore.enabledObjects.map { Activity.AssignedToken(tokenObject: $0) }
        refreshBalance(tokenObjects: Array(tokenObjects), updatePolicy: .all, force: false)
    }

    private func refreshBalanceForTokensThatAreNotNonTicket721(tokens: [Activity.AssignedToken], group: DispatchGroup) {
        assert(!tokens.contains { $0.isERC721AndNotForTickets })

        for tokenObject in tokens {
            group.enter()

            refreshBalance(forToken: tokenObject, tokensDatastore: tokensDatastore) { [weak self] balanceValueHasChange in
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
        getNativeCryptoCurrencyBalanceCoordinator.getBalance(for: account.address) { [weak self] result in
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

        let nonERC721Tokens = updateTokens.filter { !$0.isERC721AndNotForTickets }
        let erc721Tokens = updateTokens.filter { $0.isERC721AndNotForTickets }

        refreshBalanceForTokensThatAreNotNonTicket721(tokens: nonERC721Tokens, group: group)
        refreshBalanceForERC721Tokens(tokens: erc721Tokens, group: group)
    }

    private func refreshBalance(forToken tokenObject: Activity.AssignedToken, tokensDatastore: PrivateTokensDatastoreType, completion: @escaping (Bool?) -> Void) {
        switch tokenObject.type {
        case .nativeCryptocurrency:
            completion(nil)
        case .erc20:
            getERC20Balance(for: tokenObject.contractAddress, completion: { result in
                switch result {
                case .success(let balance):
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .value(balance), completion: completion)
                case .failure:
                    completion(nil)
                }
            })
        case .erc875:
            getERC875Balance(for: tokenObject.contractAddress, completion: { result in
                switch result {
                case .success(let balance):
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(balance), completion: completion)
                case .failure:
                    completion(nil)
                }
            })
        case .erc721:
            break
        case .erc721ForTickets:
            getERC721ForTicketsBalance(for: tokenObject.contractAddress, completion: { result in
                switch result {
                case .success(let balance):
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(balance), completion: completion)
                case .failure:
                    completion(nil)
                }
            })
        }
    }

    private func refreshBalanceForERC721Tokens(tokens: [Activity.AssignedToken], group: DispatchGroup) {
        assert(!tokens.contains { !$0.isERC721AndNotForTickets })
        firstly {
            getTokensFromOpenSea()
        }.done { [weak self] contractToOpenSeaNonFungibles in
            guard let strongSelf = self else { return }
            let erc721ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721ContractsFoundInOpenSea
            strongSelf.updateNonOpenSeaNonFungiblesBalance(erc721ContractsNotFoundInOpenSea: erc721ContractsNotFoundInOpenSea, tokens: tokens, group: group)
            strongSelf.updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, tokens: tokens, group: group)
        }.cauterize()
    }

    private func updateNonOpenSeaNonFungiblesBalance(erc721ContractsNotFoundInOpenSea contracts: [AlphaWallet.Address], tokens: [Activity.AssignedToken], group: DispatchGroup) {
        let promises = contracts.map { updateNonOpenSeaNonFungiblesBalance(contract: $0, tokens: tokens, tokensDatastore: tokensDatastore) }
        group.enter()

        firstly {
            when(resolved: promises)
        }.done { _ in
            group.leave()
        }
    }

    private func updateNonOpenSeaNonFungiblesBalance(contract: AlphaWallet.Address, tokens: [Activity.AssignedToken], tokensDatastore: PrivateTokensDatastoreType) -> Promise<Void> {
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

    private func fetchNonFungibleJson(forTokenId tokenId: String, address: AlphaWallet.Address, tokens: [Activity.AssignedToken]) -> Guarantee<String> {
        firstly {
            Erc721Contract(server: server).getErc721TokenUri(for: tokenId, contract: address)
        }.then {
            self.fetchTokenJson(forTokenId: tokenId, uri: $0, address: address, tokens: tokens)
        }.recover { _ in
            var jsonDictionary = JSON()
            if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                jsonDictionary["tokenId"] = JSON(tokenId)
                jsonDictionary["contractName"] = JSON(tokenObject.name)
                jsonDictionary["symbol"] = JSON(tokenObject.symbol)
                jsonDictionary["name"] = ""
                jsonDictionary["imageUrl"] = ""
                jsonDictionary["thumbnailUrl"] = ""
                jsonDictionary["externalLink"] = ""
            }
            return .value(jsonDictionary.rawString()!)
        }
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
                        //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                        jsonDictionary["tokenId"] = JSON(tokenId)
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

    private func updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]], tokens: [Activity.AssignedToken], group: DispatchGroup) {
        for (contract, openSeaNonFungibles) in contractToOpenSeaNonFungibles {
            group.enter()
            tokensDatastore.addOrUpdateErc271(contract: contract, openSeaNonFungibles: openSeaNonFungibles, tokens: tokens) { [weak self] in
                guard let strongSelf = self else {
                    group.leave()
                    return
                }

                group.leave()
                strongSelf.delegate?.didUpdate(in: strongSelf)
            }
        }
    }
}
