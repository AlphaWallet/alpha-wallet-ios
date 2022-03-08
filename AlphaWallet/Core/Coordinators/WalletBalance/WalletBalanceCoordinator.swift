//
//  WalletBalanceCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.05.2021.
//

import UIKit 
import BigInt
import PromiseKit

protocol WalletBalanceCoordinatorType: AnyObject {
    var subscribableWalletsSummary: Subscribable<WalletSummary> { get }

    func subscribableWalletBalance(wallet: Wallet) -> Subscribable<WalletBalance>
    func subscribableTokenBalance(addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel>
    func start()
    func refreshBalance() -> Promise<Void>
    func refreshEthBalance() -> Promise<Void>
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
    
    func transactionsStorage(wallet: Wallet, server: RPCServer) -> TransactionsStorage
}

class WalletBalanceCoordinator: NSObject, WalletBalanceCoordinatorType {

    private let keystore: Keystore
    private let config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    private var coinTickersFetcher: CoinTickersFetcherType
    private var subscribableEnabledServersSubscriptionKey: Subscribable<[RPCServer]>.SubscribableKey!
    private var walletsSubscriptionKey: Subscribable<Set<Wallet>>.SubscribableKey!
    private var balanceFetchers: [Wallet: WalletBalanceFetcherType] = [:]

    private lazy var servers: [RPCServer] = config.enabledServers
    private (set) lazy var subscribableWalletsSummary: Subscribable<WalletSummary> = .init(nil)
    private let queue: DispatchQueue = DispatchQueue(label: "com.WalletBalanceCoordinator.updateQueue")

    init(keystore: Keystore, config: Config, assetDefinitionStore: AssetDefinitionStore, coinTickersFetcher: CoinTickersFetcherType) {
        self.keystore = keystore
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.coinTickersFetcher = coinTickersFetcher
        super.init()

        walletsSubscriptionKey = keystore.subscribableWallets.subscribe { [weak self] wallets in
            guard let wallets = wallets, let strongSelf = self else { return }

            for wallet in wallets {
                if strongSelf.balanceFetchers[wallet] != nil {
                    //no-op
                } else {
                    let object = strongSelf.createWalletBalanceFetcher(wallet: wallet)
                    object.start()

                    strongSelf.balanceFetchers[wallet] = object
                }
            }

            //NOTE: we need to remove all balance fetcher for deleted wallets
            let handlertToDelete = strongSelf.balanceFetchers.filter { !wallets.contains($0.key) }
            for value in handlertToDelete {
                strongSelf.balanceFetchers.removeValue(forKey: value.key)
            }
        }

        subscribableEnabledServersSubscriptionKey = config.subscribableEnabledServers.subscribe { [weak self] servers in
            guard let servers = servers, let strongSelf = self else { return }

            strongSelf.servers = servers

            for fetcher in strongSelf.balanceFetchers {
                fetcher.value.update(servers: servers)
            }
        }
    }

    func subscribableTokenBalance(addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel> {
        if let pair = balanceFetchers[keystore.currentWallet] {
            return pair.subscribableTokenBalance(addressAndRPCServer: addressAndRPCServer)
        }
        return .init(nil)
    }

    func refreshBalance() -> Promise<Void> {
        guard let promise = balanceFetchers[keystore.currentWallet].flatMap({ $0.refreshBalance() }) else { return .value(()) }
        return promise
    }

    func refreshEthBalance() -> Promise<Void> {
        guard let promise = balanceFetchers[keystore.currentWallet].flatMap({ $0.refreshEthBalance() }) else { return .value(()) }
        return promise
    }

    ///Refreshes available wallets balances
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void> {
        let promises = keystore.wallets.compactMap { wallet in
            balanceFetchers[wallet]?.refreshBalance(updatePolicy: updatePolicy, force: force)
        }
        return when(resolved: promises).asVoid()
    }

    func start() {
        queue.async { [weak self] in
            self?.fetchTokenPrices()
            self?.notifyWalletSummary()
        }
    }

    func transactionsStorage(wallet: Wallet, server: RPCServer) -> TransactionsStorage {
        balanceFetchers[wallet]!.transactionsStorage(server: server)
    } 

        //NOTE: for case if we disable rpc server, we don't fetch ticker for its native crypto
    private static var nativeCryptoForAllChains: [Activity.AssignedToken] {
        return RPCServer.allCases.map { server in
            Activity.AssignedToken.init(tokenObject: MultipleChainsTokensDataStore.functional.etherToken(forServer: server))
        }
    }

    private var availableTokenObjects: Promise<ServerDictionary<[TokenMappedToTicker]>> {
        Promise<[Activity.AssignedToken]> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let tokenObjects = strongSelf.balanceFetchers.map { $0.value.tokenObjects }.flatMap { $0 }
                
                seal.fulfill(tokenObjects + Self.nativeCryptoForAllChains)
            }
        }.map(on: queue, { objects -> ServerDictionary<[TokenMappedToTicker]> in
            let tokenObjects = objects.filter { !$0.server.isTestnet }
            let uniqueTokenObjectsOfAllWallets = Set(tokenObjects)

            var tokens = ServerDictionary<[TokenMappedToTicker]>()

            for each in uniqueTokenObjectsOfAllWallets {
                var array: [TokenMappedToTicker]
                if let value = tokens[safe: each.server] {
                    array = value
                } else {
                    array = .init()
                }

                array.append(TokenMappedToTicker(token: each))

                tokens[each.server] = array
            }
            return tokens
        })
    }

    private func createWalletBalanceFetcher(wallet: Wallet) -> WalletBalanceFetcherType {
        let fetcher = WalletBalanceFetcher(wallet: wallet, keystore: keystore, servers: servers, assetDefinitionStore: assetDefinitionStore, queue: queue, coinTickersFetcher: coinTickersFetcher)
        fetcher.delegate = self

        return fetcher
    }

    func subscribableWalletBalance(wallet: Wallet) -> Subscribable<WalletBalance> {
        if let fetcher = balanceFetchers[wallet] {
            return fetcher.subscribableWalletBalance
        } else {
            let fetcher = createWalletBalanceFetcher(wallet: wallet)
            fetcher.start()

            balanceFetchers[wallet] = fetcher

            return fetcher.subscribableWalletBalance
        }
    }

    private func fetchTokenPrices() {
        firstly {
            availableTokenObjects
        }.then(on: queue, { values -> Promise<Void> in
            self.coinTickersFetcher.fetchPrices(forTokens: values.values.flatMap({ $0 }))
        }).done(on: queue, { _ in
            //no-op
        }).catch({ e in
            error(value: e)
        })
    }

    private func notifyWalletSummary() {
        firstly {
            walletSummary
        }.done({ [weak subscribableWalletsSummary] summary in
            subscribableWalletsSummary?.value = summary
        }).cauterize()
    }

    private var walletSummary: Promise<WalletSummary> {
        Promise<[WalletBalance]> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let balances = strongSelf.balanceFetchers.map { $0.value.balance }
                seal.fulfill(balances)
            }
        }.map(on: queue, { balances -> WalletSummary in
            return WalletSummary(balances: balances)
        })
    }
}

extension WalletBalanceCoordinator: WalletBalanceFetcherDelegate {

    func didAddToken(in fetcher: WalletBalanceFetcherType) {
        fetchTokenPrices()
    }

    func didUpdate(in fetcher: WalletBalanceFetcherType) {
        notifyWalletSummary()
    }
}

extension Wallet: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(address.eip55String)
    }
}
