//
//  WalletBalanceFetcherType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.05.2021.
//

import UIKit
import RealmSwift
import BigInt
import PromiseKit
import Combine

protocol WalletBalanceFetcherDelegate: AnyObject {
    func didAddToken(in fetcher: WalletBalanceFetcherType)
    func didUpdate(in fetcher: WalletBalanceFetcherType)
}

protocol WalletBalanceFetcherType: AnyObject {
    var tokenObjects: [Activity.AssignedToken] { get }
    var balance: WalletBalance { get }
    var subscribableWalletBalance: Subscribable<WalletBalance> { get }

    var isRunning: Bool { get }

    func subscribableTokenBalance(addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel>
    func removeSubscribableTokenBalance(for addressAndRPCServer: AddressAndRPCServer)

    func start()
    func stop()
    func refreshEthBalance() -> Promise<Void>
    func refreshBalance() -> Promise<Void>
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
}

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private var balanceFetchers: ServerDictionary<PrivateBalanceFetcherType> = .init()
    private let queue: DispatchQueue
    private var cache: ThreadSafeDictionary<AddressAndRPCServer, (NotificationToken, Subscribable<BalanceBaseViewModel>)> = .init()
    private let coinTickersFetcher: CoinTickersFetcherType
    private lazy var tokensDataStore: TokensDataStore = {
        return MultipleChainsTokensDataStore(realm: realm, account: wallet, servers: config.enabledServers)
    }()
    private let keystore: Keystore
    private lazy var transactionsStorage = TransactionDataStore(realm: realm, delegate: self)
    private lazy var realm = Wallet.functional.realm(forAccount: wallet)

    weak var delegate: WalletBalanceFetcherDelegate?
    var tokenObjects: [Activity.AssignedToken] {
        //NOTE: replace with more clear solution
        tokensDataStore
            .enabledTokenObjects(forServers: Array(balanceFetchers.keys))
            .map { Activity.AssignedToken(tokenObject: $0) }
    }
    private (set) lazy var subscribableWalletBalance: Subscribable<WalletBalance> = .init(balance)
    private var cancelable = Set<AnyCancellable>()
    private let config: Config

    required init(wallet: Wallet, keystore: Keystore, config: Config, assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue, coinTickersFetcher: CoinTickersFetcherType) {
        self.wallet = wallet
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.queue = queue
        self.coinTickersFetcher = coinTickersFetcher
        self.config = config
        super.init()

        for each in config.enabledServers {
            balanceFetchers[each] = createServices(wallet: wallet, server: each)
        }

        config.enabledServersPublisher
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { servers in
                self.update(servers: servers)
            }.store(in: &cancelable)

        coinTickersFetcher.tickersSubscribable.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.notifyUpdateBalance()
                strongSelf.notifyUpdateTokenBalancesSubscribers()
            }
        }
    }

    private func createServices(wallet: Wallet, server: RPCServer) -> PrivateBalanceFetcher {
        let balanceFetcher = PrivateBalanceFetcher(account: wallet, keystore: keystore, tokensDataStore: tokensDataStore, server: server, assetDefinitionStore: assetDefinitionStore, queue: queue)
        balanceFetcher.erc721TokenIdsFetcher = transactionsStorage
        balanceFetcher.delegate = self

        return balanceFetcher
    }

    private func update(servers: [RPCServer]) {
        for each in servers {
            //NOTE: when we change servers it might happen the case when native 
            tokensDataStore.addEthToken(forServer: each)

            if balanceFetchers[safe: each] != nil {
                //no-op
            } else {
                balanceFetchers[each] = createServices(wallet: wallet, server: each)
            }
        }

        let deletedServers = balanceFetchers.filter { !servers.contains($0.key) }.map { $0.key }
        for each in deletedServers {
            balanceFetchers.remove(at: each)
        }

        queue.async { [weak self] in 
            guard let strongSelf = self else { return }

            strongSelf.notifyUpdateBalance()
            strongSelf.notifyUpdateTokenBalancesSubscribers()
        }
    }

    private func notifyUpdateTokenBalancesSubscribers() {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            for (key, each) in strongSelf.cache.values {
                guard let tokenObject = strongSelf.tokensDataStore.token(forContract: key.address, server: key.server) else { continue }

                each.1.value = strongSelf.balanceViewModel(key: tokenObject)
            }
        }
    }

    private func notifyUpdateBalance() {
        Promise<WalletBalance> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let value = strongSelf.balance

                seal.fulfill(value)
            }
        }.get(on: .main, { [weak self] balance in
            self?.subscribableWalletBalance.value = balance
        }).done(on: queue, { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.didUpdate(in: strongSelf)
        }).cauterize()
    }

    private func balanceViewModel(key tokenObject: TokenObject) -> BalanceBaseViewModel? {
        let ticker = coinTickersFetcher.ticker(for: tokenObject.addressAndRPCServer)

        switch tokenObject.type {
        case .nativeCryptocurrency:
            let balance = Balance(value: BigInt(tokenObject.value, radix: 10) ?? BigInt(0))
            return NativecryptoBalanceViewModel(server: tokenObject.server, balance: balance, ticker: ticker)
        case .erc20:
            let balance = ERC20Balance(tokenObject: tokenObject)
            return ERC20BalanceViewModel(server: tokenObject.server, balance: balance, ticker: ticker)
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            return nil
        }
    }

    func removeSubscribableTokenBalance(for addressAndRPCServer: AddressAndRPCServer) {
        if let value = cache[addressAndRPCServer] {
            value.0.invalidate()
            value.1.unsubscribeAll()

            cache[addressAndRPCServer] = .none
        }
    }

    func subscribableTokenBalance(addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel> {
        guard let tokenObject = tokensDataStore.token(forContract: addressAndRPCServer.address, server: addressAndRPCServer.server) else {
            return .init(nil)
        }

        if let value = cache[addressAndRPCServer] {
            return value.1
        } else {
            let balance = balanceViewModel(key: tokenObject)
            let subscribable = Subscribable<BalanceBaseViewModel>(balance)

            let observation = tokenObject.observe(on: queue) { [weak self] change in
                guard let strongSelf = self else { return }

                switch change {
                case .change(let object, let properties):
                    if let tokenObject = object as? TokenObject, properties.isBalanceUpdate {
                        let balance = strongSelf.balanceViewModel(key: tokenObject)
                        subscribable.value = balance
                    }

                case .deleted, .error:
                    break
                }
            }

            cache[addressAndRPCServer] = (observation, subscribable)

            return subscribable
        }
    }

    var balance: WalletBalance {
        var balances = Set<Activity.AssignedToken>()

        for var tokenObject in tokenObjects {
            tokenObject.ticker = coinTickersFetcher.ticker(for: tokenObject.addressAndRPCServer)

            balances.insert(tokenObject)
        }

        return .init(wallet: wallet, values: balances)
    }

    var isRunning: Bool {
        if let timer = timer {
            return timer.isValid
        } else {
            return false
        }
    }

    func start() {
        timedCallForBalanceRefresh().done { _ in

        }.cauterize()

        timer = Timer.scheduledTimer(withTimeInterval: Self.updateBalanceInterval, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.timedCallForBalanceRefresh().done { _ in

                }.cauterize()
            }
        }
    }

    private func timedCallForBalanceRefresh() -> Promise<Void> {
        let promises = balanceFetchers.map { each in
            each.value.refreshBalance(updatePolicy: .all, force: false)
        }
        return when(resolved: promises).asVoid()
    }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void> {
        let promises = balanceFetchers.map { each in
            each.value.refreshBalance(updatePolicy: updatePolicy, force: force)
        }
        return when(resolved: promises).asVoid()
    }

    func refreshEthBalance() -> Promise<Void> {
        let promises = balanceFetchers.map { each in
            each.value.refreshBalance(updatePolicy: .eth, force: true)
        }
        return when(resolved: promises).asVoid()
    }

    func refreshBalance() -> Promise<Void> {
        let promises = balanceFetchers.map { each in
            each.value.refreshBalance(updatePolicy: .ercTokens, force: true)
        }

        return when(resolved: promises).asVoid()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

extension WalletBalanceFetcher: PrivateTokensDataStoreDelegate {

    func didAddToken(in tokensDataStore: PrivateBalanceFetcher) {
        delegate?.didAddToken(in: self)
    }

    func didUpdate(in tokensDataStore: PrivateBalanceFetcher) {
        notifyUpdateBalance()
    }
}

extension WalletBalanceFetcher: TransactionDataStoreDelegate {
    func didAddTokensWith(contracts: [AlphaWallet.Address], in transactionsStorage: TransactionDataStore) {
        for each in contracts {
            assetDefinitionStore.fetchXML(forContract: each)
        }
    }
}

fileprivate extension Array where Element == PropertyChange {
    var isBalanceUpdate: Bool {
        contains(where: { $0.name == "value" || $0.name == "balance" })
    }
}
