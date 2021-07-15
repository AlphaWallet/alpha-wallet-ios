//
//  WalletBalanceFetcherType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.05.2021.
//

import UIKit
import RealmSwift
import BigInt

protocol WalletBalanceFetcherDelegate: class {
    func didAddToken(in fetcher: WalletBalanceFetcherType)
    func didUpdate(in fetcher: WalletBalanceFetcherType)
}

protocol WalletBalanceFetcherType: class {
    var tokenObjects: [Activity.AssignedToken] { get }
    var balance: WalletBalance { get }
    var subscribableWalletBalance: Subscribable<WalletBalance> { get }

    var isRunning: Bool { get }

    func subscribableTokenBalance(addressAndRPCServer: AddressAndRPCServer) -> Subscribable<BalanceBaseViewModel>
    func removeSubscribableTokenBalance(for addressAndRPCServer: AddressAndRPCServer)

    func start()
    func stop()
    func update(servers: [RPCServer])
}

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private (set) lazy var subscribableWalletBalance: Subscribable<WalletBalance> = .init(balance)
    let tokensChangeSubscribable: Subscribable<Void> = .init(nil)
    private var tokensDataStores: ServerDictionary<(PrivateTokensDatastoreType, PrivateBalanceFetcherType)> = .init()

    var tokenObjects: [Activity.AssignedToken] {
        tokensDataStores.flatMap { $0.value.0.tokenObjects }
    }

    private let queue: DispatchQueue
    private var cache: ThreadSafeDictionary<AddressAndRPCServer, (NotificationToken, Subscribable<BalanceBaseViewModel>)> = .init()
    private let coinTickersFetcher: CoinTickersFetcherType

    weak var delegate: WalletBalanceFetcherDelegate?

    private lazy var realm = Self.realm(forAccount: wallet)

    required init(wallet: Wallet, servers: [RPCServer], queue: DispatchQueue, coinTickersFetcher: CoinTickersFetcherType) {
        self.wallet = wallet
        self.queue = queue
        self.coinTickersFetcher = coinTickersFetcher

        super.init()

        for each in servers {
            let tokensDatastore: PrivateTokensDatastoreType = PrivateTokensDatastore(realm: realm, server: each, queue: queue)
            let balanceFetcher = PrivateBalanceFetcher(account: wallet, tokensDatastore: tokensDatastore, server: each, queue: queue)
            balanceFetcher.delegate = self

            self.tokensDataStores[each] = (tokensDatastore, balanceFetcher)
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
                let tokensDatastore: PrivateTokensDatastoreType = PrivateTokensDatastore(realm: realm, server: each, queue: queue)
                let balanceFetcher = PrivateBalanceFetcher(account: wallet, tokensDatastore: tokensDatastore, server: each, queue: queue)
                balanceFetcher.delegate = self

                tokensDataStores[each] = (tokensDatastore, balanceFetcher)
            }
        }

        let delatedServers = tokensDataStores.filter{ !servers.contains($0.key) }.map{ $0.key }
        for each in delatedServers {
            tokensDataStores.remove(at: each)
        }
    }

    private func notifyUpdateTokenBalancesSubscribers() {
        for each in cache.value {
            let tokensDatastore = tokensDataStores[each.key.server]
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
        let tokensDatastore = tokensDataStores[addressAndRPCServer.server]

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

    private static func realm(forAccount account: Wallet) -> Realm {
        let migration = MigrationInitializer(account: account)
        migration.perform()

        return try! Realm(configuration: migration.config)
    }

    var isRunning: Bool {
        if let timer = timer {
            return timer.isValid
        } else {
            return false
        }
    }

    func start() {
        refreshBalance()
        
        timer = Timer.scheduledTimer(withTimeInterval: Self.updateBalanceInterval, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.refreshBalance()
            }
        }
    }

    private func refreshBalance() {
        for each in tokensDataStores {
            each.value.1.refreshBalance()
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
