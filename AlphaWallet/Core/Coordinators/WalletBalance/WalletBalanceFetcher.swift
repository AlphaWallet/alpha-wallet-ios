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
    var walletBalance: AnyPublisher<WalletBalance, Never> { get }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel, Never>
    func tokenBalance(_ key: AddressAndRPCServer) -> BalanceBaseViewModel
    func start()
    func stop() 
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
}

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private var balanceFetchers: ServerDictionary<PrivateBalanceFetcherType> = .init()
    private let queue: DispatchQueue
    private let coinTickersFetcher: CoinTickersFetcherType
    private lazy var tokensDataStore: TokensDataStore = {
        return MultipleChainsTokensDataStore(realm: realm, servers: config.enabledServers)
    }()
    private let nftProvider: NFTProvider
    private lazy var transactionsStorage = TransactionDataStore(realm: realm)
    private lazy var realm = Wallet.functional.realm(forAccount: wallet)
    private var cancelable = Set<AnyCancellable>()
    private let config: Config
    private let balanceUpdateSubject = PassthroughSubject<Void, Never>()
    private lazy var walletBalanceSubject: CurrentValueSubject<WalletBalance, Never> = .init(balance)

    weak var delegate: WalletBalanceFetcherDelegate?
    var tokenObjects: [Activity.AssignedToken] {
        //NOTE: replace with more clear solution
        tokensDataStore
            .enabledTokenObjects(forServers: Array(balanceFetchers.keys))
            .map { Activity.AssignedToken(tokenObject: $0) }
    }

    var walletBalance: AnyPublisher<WalletBalance, Never> {
        return walletBalanceSubject
            .eraseToAnyPublisher()
    }

    required init(wallet: Wallet, nftProvider: NFTProvider, config: Config, assetDefinitionStore: AssetDefinitionStore, queue: DispatchQueue, coinTickersFetcher: CoinTickersFetcherType) {
        self.wallet = wallet
        self.nftProvider = nftProvider
        self.assetDefinitionStore = assetDefinitionStore
        self.queue = queue
        self.coinTickersFetcher = coinTickersFetcher
        self.config = config
        super.init()

        for each in config.enabledServers {
            balanceFetchers[each] = createBalanceFetcher(wallet: wallet, server: each)
        }

        config.enabledServersPublisher
            .receive(on: RunLoop.main)
            .sink { servers in
                self.update(servers: servers)
            }.store(in: &cancelable)

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

    private func update(servers: [RPCServer]) {
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

    private func balanceViewModel(key tokenObject: TokenObject) -> BalanceBaseViewModel {
        let ticker = coinTickersFetcher.ticker(for: tokenObject.addressAndRPCServer)

        switch tokenObject.type {
        case .nativeCryptocurrency:
            let balance = Balance(value: BigInt(tokenObject.value, radix: 10) ?? BigInt(0))
            return NativecryptoBalanceViewModel(server: tokenObject.server, balance: balance, ticker: ticker)
        case .erc20:
            let balance = ERC20Balance(tokenObject: tokenObject)
            return ERC20BalanceViewModel(server: tokenObject.server, balance: balance, ticker: ticker)
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            let balance = NFTBalance(tokenObject: tokenObject)
            return NFTBalanceViewModel(server: tokenObject.server, balance: balance, ticker: ticker)
        }
    }

    private func triggerUpdateBalance() {
        balanceUpdateSubject.send(())
    }

    func tokenBalance(_ key: AddressAndRPCServer) -> BalanceBaseViewModel {
        guard let tokenObject = tokensDataStore.token(forContract: key.address, server: key.server) else {
            let ticker = coinTickersFetcher.ticker(for: key)
            return NativecryptoBalanceViewModel(server: key.server, balance: Balance(value: .zero), ticker: ticker)
        }

        return balanceViewModel(key: tokenObject)
    }

    func tokenBalancePublisher(_ key: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel, Never> {
        guard let tokenObject = tokensDataStore.token(forContract: key.address, server: key.server) else {
            let ticker = coinTickersFetcher.ticker(for: key)
            let viewModel: BalanceBaseViewModel = NativecryptoBalanceViewModel(server: key.server, balance: Balance(value: .zero), ticker: ticker)
            let publisher = Just(viewModel)
                .eraseToAnyPublisher()

            return publisher
        }

        let publisher = tokenObject
            .publisher(for: \.value, options: [.new, .initial])
            .combineLatest(balanceUpdateSubject) { _, _ -> Void in return () }
            .map { _ in self.balanceViewModel(key: tokenObject) }
            .prepend(self.balanceViewModel(key: tokenObject))
            .eraseToAnyPublisher()

        return publisher
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
        let promises = balanceFetchers.map { each in
            each.value.refreshBalance(updatePolicy: updatePolicy, force: force)
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
        DispatchQueue.main.async {
            self.reloadWalletBalance()
        }
    }
}

fileprivate extension Array where Element == PropertyChange {
    var isBalanceUpdate: Bool {
        contains(where: { $0.name == "value" || $0.name == "balance" })
    }
}
