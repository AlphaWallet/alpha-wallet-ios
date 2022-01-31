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
    func update(servers: [RPCServer])
    func refreshEthBalance() -> Promise<Void>
    func refreshBalance() -> Promise<Void>
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
    func transactionsStorage(server: RPCServer) -> TransactionsStorage
}
typealias WalletBalanceFetcherSubServices = (balanceFetcher: PrivateBalanceFetcherType, transactionsStorage: TransactionsStorage)

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private (set) lazy var subscribableWalletBalance: Subscribable<WalletBalance> = .init(balance)
    private var services: ServerDictionary<WalletBalanceFetcherSubServices> = .init()
    private let queue: DispatchQueue
    private var cache: ThreadSafeDictionary<AddressAndRPCServer, (NotificationToken, Subscribable<BalanceBaseViewModel>)> = .init()
    private let coinTickersFetcher: CoinTickersFetcherType
    private lazy var tokensDatastore: TokensDataStore = {
        return MultipleChainsTokensDataStore(realm: realm, account: wallet, servers: Config().enabledServers)
    }()
    private let keystore: Keystore
    private lazy var realm = Wallet.functional.realm(forAccount: wallet)

    weak var delegate: WalletBalanceFetcherDelegate?
    var tokenObjects: [Activity.AssignedToken] {
        tokensDatastore
            .enabledTokenObjects(forServers: Array(services.keys))
            .map { Activity.AssignedToken(tokenObject: $0) }
    }

    required init(wallet: Wallet, keystore: Keystore, servers: [RPCServer], assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue, coinTickersFetcher: CoinTickersFetcherType) {
        self.wallet = wallet
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.queue = queue
        self.coinTickersFetcher = coinTickersFetcher

        super.init()
        for each in servers {
            services[each] = createServices(wallet: wallet, server: each)
        }

        coinTickersFetcher.tickersSubscribable.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.notifyUpdateBalance()
                strongSelf.notifyUpdateTokenBalancesSubscribers()
            }
        }
    }

    func transactionsStorage(server: RPCServer) -> TransactionsStorage {
        if let services = services[safe: server] {
            return services.transactionsStorage
        } else {
            let subServices = createServices(wallet: wallet, server: server)
            services[server] = subServices

            return subServices.transactionsStorage
        }
    } 

    private func createServices(wallet: Wallet, server: RPCServer) -> WalletBalanceFetcherSubServices {
        let transactionsStorage = TransactionsStorage(realm: realm, server: server, delegate: nil)
        let balanceFetcher = PrivateBalanceFetcher(account: wallet, keystore: keystore, tokensDataStore: tokensDatastore, server: server, assetDefinitionStore: assetDefinitionStore, queue: queue)
        balanceFetcher.erc721TokenIdsFetcher = transactionsStorage
        balanceFetcher.delegate = self

        return (balanceFetcher, transactionsStorage)
    }

    func update(servers: [RPCServer]) {
        for each in servers {
            if services[safe: each] != nil {
                //no-op
            } else {
                services[each] = createServices(wallet: wallet, server: each)
            }
        }

        let deletedServers = services.filter { !servers.contains($0.key) }.map { $0.key }
        for each in deletedServers {
            services.remove(at: each)
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
                guard let tokenObject = strongSelf.tokensDatastore.token(forContract: key.address, server: key.server) else { continue }

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
        guard let tokenObject = tokensDatastore.token(forContract: addressAndRPCServer.address, server: addressAndRPCServer.server) else {
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
        let promises = services.map { each in
            each.value.balanceFetcher.refreshBalance(updatePolicy: .all, force: false)
        }
        return when(resolved: promises).asVoid()
    }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void> {
        let promises = services.map { each in
            each.value.balanceFetcher.refreshBalance(updatePolicy: updatePolicy, force: force)
        }
        return when(resolved: promises).asVoid()
    }

    func refreshEthBalance() -> Promise<Void> {
        let promises = services.map { each in
            each.value.balanceFetcher.refreshBalance(updatePolicy: .eth, force: true)
        }
        return when(resolved: promises).asVoid()
    }

    func refreshBalance() -> Promise<Void> {
        let promises = services.map { each in
            each.value.balanceFetcher.refreshBalance(updatePolicy: .ercTokens, force: true)
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

fileprivate extension Array where Element == PropertyChange {
    var isBalanceUpdate: Bool {
        contains(where: { $0.name == "value" || $0.name == "balance" })
    }
}
