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

protocol PrivateTokensDataStoreDelegate: class {
    func didUpdate(in tokensDataStore: PrivateBalanceFetcher)
    func didAddToken(in tokensDataStore: PrivateBalanceFetcher)
}

protocol PrivateBalanceFetcherType: class {
    var delegate: PrivateTokensDataStoreDelegate? { get set }

    func refreshBalance()
}

class PrivateBalanceFetcher: PrivateBalanceFetcherType {
    static let fetchContractDataTimeout = TimeInterval(4)

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

                strongSelf.refreshBalance(tokenObjects: Array(tokenObjects), force: true)
            case .update(let updates, _, let insertions, _):
                let values = updates.map { Activity.AssignedToken(tokenObject: $0) }
                let tokenObjects = insertions.map { values[$0] }
                guard !tokenObjects.isEmpty else { return }

                strongSelf.refreshBalance(tokenObjects: tokenObjects, force: true)

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

    func refreshBalance() {
        let tokenObjects = tokensDatastore.enabledObjects.map { Activity.AssignedToken(tokenObject: $0) }
        refreshBalance(tokenObjects: Array(tokenObjects), force: false)
    }

    private func refreshBalance(tokenObjects: [Activity.AssignedToken], force: Bool = false) {
        guard !isRefeshingBalance || force else { return }

        isRefeshingBalance = true
        let group: DispatchGroup = .init()

        let nonERC721Tokens = tokenObjects.filter { !$0.isERC721AndNotForTickets }
        //let erc721Tokens = tokenObjects.filter { $0.isERC721AndNotForTickets }

        refreshBalanceForTokensThatAreNotNonTicket721(tokens: nonERC721Tokens, group: group)
        //NOTE: Disable updating balance for ERC721 for now. need to pull upstream version, and update logic
        //refreshBalanceForERC721Tokens(tokens: erc721Tokens, group: group, tokensDatastore: tokensDatastore)

        group.notify(queue: backgroundQueue) {
            self.isRefeshingBalance = false
        }
    }

    private func refreshBalanceForTokensThatAreNotNonTicket721(tokens: [Activity.AssignedToken], group: DispatchGroup) {
        for tokenObject in tokens {
            group.enter()

            refreshBalance(forToken: tokenObject, tokensDatastore: tokensDatastore) { [weak self] balanceValueHasChange in
                guard let strongSelf = self, let delegate = strongSelf.delegate else { return }

                if let value = balanceValueHasChange, value {
                    delegate.didUpdate(in: strongSelf)
                }
                
                group.leave()
            }
        }
    }

    private func refreshBalance(forToken tokenObject: Activity.AssignedToken, tokensDatastore: PrivateTokensDatastoreType, completion: @escaping (Bool?) -> Void) {
        switch tokenObject.type {
        case .nativeCryptocurrency:
            getNativeCryptoCurrencyBalanceCoordinator.getBalance(for: account.address) { result in
                switch result {
                case .success(let balance):
                    tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .value(balance.value), completion: completion)
                case .failure:
                    completion(nil)
                }
            }
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

    private func refreshBalanceForERC721Tokens(tokens: [Activity.AssignedToken], group: DispatchGroup, tokensDatastore: PrivateTokensDatastoreType) {
        guard OpenSea.isServerSupported(server) else { return }

        getTokensFromOpenSea().done { [weak self] contractToOpenSeaNonFungibles in
            guard let strongSelf = self else { return }
            let erc721ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721ContractsFoundInOpenSea

            for address in erc721ContractsNotFoundInOpenSea {
                group.enter()
                strongSelf.getERC721Balance(for: address) { [weak self] result in
                    guard let strongSelf = self else { return }

                    switch result {
                    case .success(let balance):
                        if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                            tokensDatastore.update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(balance)) { _ in
                                group.leave()
                                strongSelf.delegate?.didUpdate(in: strongSelf)
                            }
                        }
                    case .failure:
                        group.leave()
                    }
                }
            }

            for (contract, openSeaNonFungibles) in contractToOpenSeaNonFungibles {
                group.enter()
                tokensDatastore.addOrUpdateErc271(contract: contract, openSeaNonFungibles: openSeaNonFungibles, tokens: tokens) { [weak self] in
                    guard let strongSelf = self else { return }

                    group.leave()
                    strongSelf.delegate?.didUpdate(in: strongSelf)
                }
            }
        }.cauterize()
    }
}
