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
    func didUpdate(in fetcher: WalletBalanceFetcherType)
}

protocol WalletBalanceFetcherTypeTests {
    func setBalanceTestsOnly(_ value: BigInt, forToken token: TokenObject)
    func deleteTokenTestsOnly(token: TokenObject)
    func addOrUpdateTokenTestsOnly(token: TokenObject)
    func triggerUpdateBalanceSubjectTestsOnly()
}

protocol WalletBalanceFetcherType: AnyObject, WalletBalanceFetcherTypeTests {
    var balance: WalletBalance { get }
    var walletBalancePublisher: AnyPublisher<WalletBalance, Never> { get }
    var walletBalance: WalletBalance { get }
    var tokensDataStore: TokensDataStore { get }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel?, Never>
    func tokenBalance(_ key: AddressAndRPCServer) -> BalanceBaseViewModel?
    func start()
    func stop()
    func update(servers: [RPCServer])
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy)
}

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private var balanceFetchers: AtomicDictionary<RPCServer, PrivateBalanceFetcherType> = .init()
    private let queue: DispatchQueue
    private let coinTickersFetcher: CoinTickersFetcherType
    let tokensDataStore: TokensDataStore
    private let nftProvider: NFTProvider
    private let transactionsStorage: TransactionDataStore
    private var cancelable = Set<AnyCancellable>()
    private let config: Config
    private let balanceUpdateSubject = PassthroughSubject<Void, Never>()
    private lazy var walletBalanceSubject: CurrentValueSubject<WalletBalance, Never> = .init(balance)
    private var servers: CurrentValueSubject<[RPCServer], Never>

    weak var delegate: WalletBalanceFetcherDelegate?

    var walletBalancePublisher: AnyPublisher<WalletBalance, Never> {
        return walletBalanceSubject
            .removeDuplicates()
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
        self.servers = .init(servers)
        super.init()

        for each in servers {
            balanceFetchers[each] = createBalanceFetcher(wallet: wallet, server: each)
        }

        subscribeForTickerUpdates()
        subscribeForTokenUpdates()
    }

    private static var nativeCryptoForAllChains: [Activity.AssignedToken] = {
        return RPCServer.allCases
            .map { MultipleChainsTokensDataStore.functional.etherToken(forServer: $0) }
            .map { Activity.AssignedToken(tokenObject: $0) }
    }()

    private func subscribeForTokenUpdates() {
        servers.compactMap { [weak tokensDataStore] in tokensDataStore?.initialOrNewTokensPublisher(forServers: $0) }
            .switchToLatest()
            .receive(on: queue)
            .sink { [weak coinTickersFetcher] tokens in
                let tokens = (tokens + Self.nativeCryptoForAllChains).filter { !$0.server.isTestnet }
                let uniqueTokens = Set(tokens).map { TokenMappedToTicker(token: $0) }

                coinTickersFetcher?.fetchPrices(forTokens: uniqueTokens)
            }.store(in: &cancelable)
    }

    private func subscribeForTickerUpdates() {
        coinTickersFetcher
            .tickersUpdatedPublisher
            .receive(on: queue)
            .sink { [weak self] _ in
                self?.reloadWalletBalance()
                self?.triggerUpdateBalance()
            }.store(in: &cancelable)
    }

    private func subscribeForTokenUpdates(forServer server: RPCServer) {
        tokensDataStore
            .initialOrNewTokensPublisher(forServers: [server])
            .receive(on: queue)
            .sink { [weak self] tokens in
                guard let balanceFetcher = self?.balanceFetchers[server] else { return }

                balanceFetcher.refreshBalance(forTokens: tokens)
            }.store(in: &cancelable)
    }

    func triggerUpdateBalanceSubjectTestsOnly() {
        triggerUpdateBalance()
    }
    
    private func createBalanceFetcher(wallet: Wallet, server: RPCServer) -> PrivateBalanceFetcherType {
        let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        let balanceFetcher = PrivateBalanceFetcher(account: wallet, nftProvider: nftProvider, tokensDataStore: tokensDataStore, etherToken: Activity.AssignedToken(tokenObject: etherToken), server: server, config: config, assetDefinitionStore: assetDefinitionStore, queue: queue)
        balanceFetcher.erc721TokenIdsFetcher = transactionsStorage
        balanceFetcher.delegate = self

        subscribeForTokenUpdates(forServer: server)

        return balanceFetcher
    }

    @discardableResult private func getOrCreateBalanceFetcher(server: RPCServer) -> PrivateBalanceFetcherType {
        if let fetcher = balanceFetchers[server] {
            return fetcher
        } else {
            let service = createBalanceFetcher(wallet: wallet, server: server)
            balanceFetchers[server] = service
            return service
        }
    }

    func update(servers: [RPCServer]) {
        self.servers.send(servers)

        for each in servers {
            //NOTE: when we change servers it might happen the case when native
            tokensDataStore.addEthToken(forServer: each)
            getOrCreateBalanceFetcher(server: each)
        }

        filterAwayDeletedBalanceFetchers(servers: servers)

        reloadWalletBalance()
        triggerUpdateBalance()
    }

    private func filterAwayDeletedBalanceFetchers(servers: [RPCServer]) {
        let deletedServers = balanceFetchers.values.filter { !servers.contains($0.key) }.map { $0.key }
        for each in deletedServers {
            balanceFetchers.removeValue(forKey: each)
        }
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
        let tokensDataStore = tokensDataStore

        let tokenPublisher = tokensDataStore
            .tokenValuePublisher(forContract: key.address, server: key.server)
            .replaceError(with: nil)

        let forceReloadBalanceWhenServersChange = balanceUpdateSubject
            .map { _ in tokensDataStore.token(forContract: key.address, server: key.server) }
            .replaceError(with: nil)
            .eraseToAnyPublisher()

        let initialyTokenValuePublisher = Just(tokensDataStore.token(forContract: key.address, server: key.server))
            .replaceError(with: nil)
            .eraseToAnyPublisher()

        return Publishers.Merge(forceReloadBalanceWhenServersChange, tokenPublisher)
            .prepend(initialyTokenValuePublisher)
            .map { $0.flatMap { self.balanceViewModel(forToken: $0) } }
            .eraseToAnyPublisher()
    }

    var balance: WalletBalance {
        let tokens = tokensDataStore.enabledTokenObjects(forServers: Array(balanceFetchers.values.keys))
        return .init(wallet: wallet, tokens: tokens, coinTickersFetcher: coinTickersFetcher)
    }

    func start() {
        refreshBalance(updatePolicy: .all)
        timer = Timer.scheduledTimer(withTimeInterval: Self.updateBalanceInterval, repeats: true) { [weak self] _ in
            self?.refreshBalance(updatePolicy: .all)
        }
    }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy) {
        queue.async {
            switch updatePolicy {
            case .token(let token):
                guard let fetcher = self.balanceFetchers[token.server] else { return }
                fetcher.refreshBalance(forTokens: [token])
            case .all:
                for (server, fetcher) in self.balanceFetchers.values {
                    let tokens = self.tokensDataStore.enabledTokenObjects(forServers: [server]).map { Activity.AssignedToken(tokenObject: $0) }
                    fetcher.refreshBalance(forTokens: tokens)
                }
            case .eth:
                for (_, fetcher) in self.balanceFetchers.values {
                    fetcher.refreshBalance(forTokens: [fetcher.etherToken])
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

extension WalletBalanceFetcher: PrivateBalanceFetcherDelegate {
    func didUpdateBalance(value operations: [PrivateBalanceFetcher.TokenBatchOperation], in fetcher: PrivateBalanceFetcher) {
        guard !operations.isEmpty else { return }

        if let balanceHasUpdated = tokensDataStore.batchUpdateToken(operations), balanceHasUpdated {
            reloadWalletBalance()
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
