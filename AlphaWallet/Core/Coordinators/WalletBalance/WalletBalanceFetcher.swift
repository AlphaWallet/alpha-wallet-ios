//
//  WalletBalanceFetcherType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.05.2021.
//

import UIKit
import RealmSwift
import BigInt

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
    func refreshEthBalance()
    func refreshBalance()
}

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private (set) lazy var subscribableWalletBalance: Subscribable<WalletBalance> = .init(balance)
    let tokensChangeSubscribable: Subscribable<Void> = .init(nil)
    private var tokensDataStores: ServerDictionary<(PrivateTokensDatastoreType, PrivateBalanceFetcherType, TransactionsStorage)> = .init()

    var tokenObjects: [Activity.AssignedToken] {
        tokensDataStores.flatMap { $0.value.0.tokenObjects }
    }

    private let queue: DispatchQueue
    private var cache: ThreadSafeDictionary<AddressAndRPCServer, (NotificationToken, Subscribable<BalanceBaseViewModel>)> = .init()
    private let coinTickersFetcher: CoinTickersFetcherType

    weak var delegate: WalletBalanceFetcherDelegate?

    private lazy var realm = Wallet.functional.realm(forAccount: wallet)

    required init(wallet: Wallet, servers: [RPCServer], assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue, coinTickersFetcher: CoinTickersFetcherType) {
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.queue = queue
        self.coinTickersFetcher = coinTickersFetcher

        super.init()

        for each in servers {
            let transactionsStorage = TransactionsStorage(realm: realm, server: each, delegate: nil)
            let tokensDatastore: PrivateTokensDatastoreType = PrivateTokensDatastore(realm: realm, server: each, queue: queue)
            let balanceFetcher = PrivateBalanceFetcher(account: wallet, tokensDatastore: tokensDatastore, server: each, assetDefinitionStore: assetDefinitionStore, queue: queue)
            balanceFetcher.erc721TokenIdsFetcher = transactionsStorage
            balanceFetcher.delegate = self

            self.tokensDataStores[each] = (tokensDatastore, balanceFetcher, transactionsStorage)
        }

        coinTickersFetcher.tickersSubscribable.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.notifyUpdateBalance()
                strongSelf.notifyUpdateTokenBalancesSubscribers()
            }
        }
    }

    func update(servers: [RPCServer]) {
        for each in servers {
            if tokensDataStores[safe: each] != nil {
                //no-op
            } else {
                let transactionsStorage = TransactionsStorage(realm: realm, server: each, delegate: nil)
                let tokensDatastore: PrivateTokensDatastoreType = PrivateTokensDatastore(realm: realm, server: each, queue: queue)
                let balanceFetcher = PrivateBalanceFetcher(account: wallet, tokensDatastore: tokensDatastore, server: each, assetDefinitionStore: assetDefinitionStore, queue: queue)
                balanceFetcher.erc721TokenIdsFetcher = transactionsStorage
                balanceFetcher.delegate = self

                tokensDataStores[each] = (tokensDatastore, balanceFetcher, transactionsStorage)
            }
        }

        let delatedServers = tokensDataStores.filter { !servers.contains($0.key) }.map { $0.key }
        for each in delatedServers {
            tokensDataStores.remove(at: each)
        }
    }

    private func notifyUpdateTokenBalancesSubscribers() {
        for each in cache.value {
            guard let tokensDatastore = tokensDataStores[safe: each.key.server] else { continue }
            guard let tokenObject = tokensDatastore.0.tokenObject(contract: each.key.address) else {
                continue
            }

            each.value.1.value = balanceViewModel(key: tokenObject)
        }
    }

    private func notifyUpdateBalance() {
        subscribableWalletBalance.value = balance

        delegate?.didUpdate(in: self)
    }

    private func balanceViewModel(key tokenObject: TokenObject) -> BalanceBaseViewModel? {
        let ticker = coinTickersFetcher.tickers[tokenObject.addressAndRPCServer]

        switch tokenObject.type {
        case .nativeCryptocurrency:
            let balance = Balance(value: BigInt(tokenObject.value, radix: 10) ?? BigInt(0))
            return NativecryptoBalanceViewModel(server: tokenObject.server, balance: balance, ticker: ticker)
        case .erc20:
            let balance = ERC20Balance(tokenObject: tokenObject)
            return ERC20BalanceViewModel(server: tokenObject.server, balance: balance, ticker: ticker)
        case .erc875, .erc721, .erc721ForTickets:
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
        guard let tokensDatastore = tokensDataStores[safe: addressAndRPCServer.server] else { return .init(nil) }

        guard let tokenObject = tokensDatastore.0.tokenObject(contract: addressAndRPCServer.address) else {
            return .init(nil)
        }

        if let value = cache[addressAndRPCServer] {
            return value.1
        } else {
            let subscribable = Subscribable<BalanceBaseViewModel>(balanceViewModel(key: tokenObject))
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
            tokenObject.ticker = coinTickersFetcher.tickers[tokenObject.addressAndRPCServer]

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
        timedCallForBalanceRefresh()

        timer = Timer.scheduledTimer(withTimeInterval: Self.updateBalanceInterval, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.timedCallForBalanceRefresh()
            }
        }
    }

    private func timedCallForBalanceRefresh() {
        for each in tokensDataStores {
            each.value.1.refreshBalance(updatePolicy: .all, force: false)
        }
    }

    func refreshEthBalance() {
        for each in tokensDataStores {
            each.value.1.refreshBalance(updatePolicy: .eth, force: true)
        }
    }

    func refreshBalance() {
        for each in tokensDataStores {
            each.value.1.refreshBalance(updatePolicy: .ercTokens, force: true)
        }
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
