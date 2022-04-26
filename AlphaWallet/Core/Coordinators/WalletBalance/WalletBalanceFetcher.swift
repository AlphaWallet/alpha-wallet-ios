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
protocol WalletBalanceFetcherTypeTests {
    func setBalanceTestsOnly(_ value: BigInt, forToken token: TokenObject)
    func deleteTokenTestsOnly(token: TokenObject)
    func addOrUpdateTokenTestsOnly(token: TokenObject)
}

protocol WalletBalanceFetcherType: AnyObject, WalletBalanceFetcherTypeTests {
    var tokenObjects: [Activity.AssignedToken] { get }
    var balance: WalletBalance { get }
    var walletBalancePublisher: AnyPublisher<WalletBalance, Never> { get }
    var walletBalance: WalletBalance { get }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel?, Never>
    func tokenBalance(_ key: AddressAndRPCServer) -> BalanceBaseViewModel?
    func start()
    func stop() 
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
    func update(servers: [RPCServer])
}

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private var balanceFetchers: ServerDictionary<PrivateBalanceFetcherType> = .init()
    private let queue: DispatchQueue
    private let coinTickersFetcher: CoinTickersFetcherType
    private let tokensDataStore: TokensDataStore
    private let nftProvider: NFTProvider
    private let transactionsStorage: TransactionDataStore
    private var cancelable = Set<AnyCancellable>()
    private let config: Config
    private let balanceUpdateSubject = PassthroughSubject<Void, Never>()
    private lazy var walletBalanceSubject: CurrentValueSubject<WalletBalance, Never> = .init(balance)
    private var servers: [RPCServer]

    weak var delegate: WalletBalanceFetcherDelegate?
    var tokenObjects: [Activity.AssignedToken] {
        //NOTE: replace with more clear solution
        tokensDataStore
            .enabledTokenObjects(forServers: Array(balanceFetchers.keys))
            .map { Activity.AssignedToken(tokenObject: $0) }
    }

    var walletBalancePublisher: AnyPublisher<WalletBalance, Never> {
        return walletBalanceSubject
            .eraseToAnyPublisher()
    }

    var walletBalance: WalletBalance {
        return walletBalanceSubject.value
    }

    required init(wallet: Wallet, servers: [RPCServer], tokensDataStore: TokensDataStore, transactionsStorage: TransactionDataStore, nftProvider: NFTProvider, config: Config, assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue, coinTickersFetcher: CoinTickersFetcherType) {
        self.wallet = wallet
        self.nftProvider = nftProvider
        self.assetDefinitionStore = assetDefinitionStore
        self.queue = queue
        self.tokensDataStore = tokensDataStore
        self.coinTickersFetcher = coinTickersFetcher
        self.config = config
        self.transactionsStorage = transactionsStorage
        self.servers = servers
        super.init()

        for each in servers {
            balanceFetchers[each] = createBalanceFetcher(wallet: wallet, server: each)
        }

        coinTickersFetcher
            .tickersUpdatedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadWalletBalance()
                self?.triggerUpdateBalance()
            }.store(in: &cancelable)
    }

    private func createBalanceFetcher(wallet: Wallet, server: RPCServer) -> PrivateBalanceFetcher {
        let balanceFetcher = PrivateBalanceFetcher(account: wallet, nftProvider: nftProvider, tokensDataStore: tokensDataStore, server: server, config: config, assetDefinitionStore: assetDefinitionStore, queue: queue)
        balanceFetcher.erc721TokenIdsFetcher = transactionsStorage
        balanceFetcher.delegate = self

        return balanceFetcher
    }

    @discardableResult private func getOrCreateBalanceFetcher(server: RPCServer) -> PrivateBalanceFetcherType {
        if let fetcher = balanceFetchers[safe: server] {
            return fetcher
        } else {
            let service = createBalanceFetcher(wallet: wallet, server: server)
            balanceFetchers[server] = service
            return service
        }
    }

    func update(servers: [RPCServer]) {
        self.servers = servers

        for each in servers {
            //NOTE: when we change servers it might happen the case when native
            tokensDataStore.addEthToken(forServer: each)
            getOrCreateBalanceFetcher(server: each)
        }

        let deletedServers = balanceFetchers.filter { !servers.contains($0.key) }.map { $0.key }
        for each in deletedServers {
            balanceFetchers.remove(at: each)
        }

        reloadWalletBalance()
        triggerUpdateBalance()
    }

    private func reloadWalletBalance() {
        walletBalanceSubject.value = balance
        delegate?.didUpdate(in: self)
    }

    private func balanceViewModel(forToken token: TokenObject) -> BalanceBaseViewModel {
        let ticker = coinTickersFetcher.ticker(for: token.addressAndRPCServer)

        switch token.type {
        case .nativeCryptocurrency:
            let balance = Balance(value: BigInt(token.value, radix: 10) ?? BigInt(0))
            return NativecryptoBalanceViewModel(server: token.server, balance: balance, ticker: ticker)
        case .erc20:
            let balance = ERC20Balance(tokenObject: token)
            return ERC20BalanceViewModel(server: token.server, balance: balance, ticker: ticker)
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            let balance = NFTBalance(tokenObject: token)
            return NFTBalanceViewModel(server: token.server, balance: balance, ticker: ticker)
        }
    }

    private func triggerUpdateBalance() {
        balanceUpdateSubject.send(())
    }

    func tokenBalance(_ key: AddressAndRPCServer) -> BalanceBaseViewModel? {
        guard let token = tokensDataStore.token(forContract: key.address, server: key.server) else {
            return nil
        }

        return balanceViewModel(forToken: token)
    }

    func tokenBalancePublisher(_ key: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel?, Never> {
        let tokenPublisher = tokensDataStore
            .tokenValuePublisher(forContract: key.address, server: key.server)
            .replaceError(with: nil)

        let forceReloadBalanceWhenServersChange = balanceUpdateSubject
            .prepend(())

        return Publishers.CombineLatest(forceReloadBalanceWhenServersChange, tokenPublisher)
            .map { $1 }
            .map { [weak self] in $0.flatMap { self?.balanceViewModel(forToken: $0) } }
            .eraseToAnyPublisher()
    }

    var balance: WalletBalance {
        var balances = Set<Activity.AssignedToken>()

        for var tokenObject in tokenObjects {
            tokenObject.ticker = coinTickersFetcher.ticker(for: tokenObject.addressAndRPCServer)

            balances.insert(tokenObject)
        }

        return .init(wallet: wallet, values: balances)
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
        switch updatePolicy {
        case .token(let token):
            guard let fetcher = balanceFetchers[safe: token.server] else { return .value(()) }
            return fetcher.refreshBalance(updatePolicy: updatePolicy, force: force)
        case .all, .eth:
            let promises = balanceFetchers.map { each in
                each.value.refreshBalance(updatePolicy: updatePolicy, force: force)
            }
            return when(resolved: promises).asVoid()
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
        DispatchQueue.main.async {
            self.reloadWalletBalance()
        }
    }
}

extension WalletBalanceFetcher: WalletBalanceFetcherTypeTests {

    func setBalanceTestsOnly(_ value: BigInt, forToken token: TokenObject) {
        tokensDataStore.updateToken(primaryKey: token.primaryKey, action: .value(value))
    }

    func deleteTokenTestsOnly(token: TokenObject) {
        tokensDataStore.deleteTestsOnly(tokens: [token])
    }

    func addOrUpdateTokenTestsOnly(token: TokenObject) {
        tokensDataStore.addTokenObjects(values: [
            .tokenObject(token)
        ])
    }

}

extension Optional where Wrapped == TokenChange {
    var initialValueOrBalanceChanged: Bool {
        guard let strongSelf = self else { return true }
        switch strongSelf.change {
        case .initial:
            return true
        case .changed(let properties):
            return properties.isBalanceUpdate
        }
    }
}

fileprivate extension Array where Element == PropertyChange {
    var isBalanceUpdate: Bool {
        contains(where: { $0.name == "value" || $0.name == "balance" })
    }
}
